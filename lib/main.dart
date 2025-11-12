import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main()async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FYP Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const AuthGate(),
    );
  }
}
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user != null) {
          if (user.emailVerified) {
            return const MyHomePage(title: 'ChickenPox/Shingles identification!!!!!');
          } else {
            return EmailVerificationScreen(user: user);
          }
        }

        return const AuthScreen();
      },
    );
  }
}
class EmailVerificationScreen extends StatefulWidget {
  final User user;
  const EmailVerificationScreen({super.key, required this.user});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isSending = false;

  // Resend email
  Future<void> _resendVerification() async {
    setState(() => _isSending = true);
    try {
      FirebaseAuth.instance.setLanguageCode('en');
      await widget.user.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent! Check your inbox.')),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending email: ${e.message}')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  // Check if user verified
  Future<void> _checkVerified() async {
    await widget.user.reload(); // Refresh user data
    if (widget.user.emailVerified) {
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MyHomePage(title: 'ChickenPox/Shingles identification!!!!!'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not verified yet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Your Email')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'A verification link has been sent to your email. Please verify to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isSending ? null : _resendVerification,
              child: _isSending
                  ? const CircularProgressIndicator()
                  : const Text('Resend Verification Email'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkVerified,
              child: const Text('I have verified my email'),
            ),
          ],
        ),
      ),
    );
  }
}


class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  String? _errorMessage;
  bool _isLoading = false;
  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Please enter your email to reset the password.";
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      setState(() {
        _errorMessage = "Password reset link sent! Check your email.";
      });

    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred during password reset.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuthForm() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      UserCredential userCredential;

      if (_isLogin) {
        // --- Sign in ---
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (!userCredential.user!.emailVerified) {
          // User hasn't verified email
          await _sendVerificationEmail(userCredential.user!);
          setState(() {
            _errorMessage =
            "Your email is not verified. A verification email has been sent. Check your inbox.";
          });
          await FirebaseAuth.instance.signOut();
          return;
        }

      } else {
        // --- Sign up ---
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Send verification email
        await _sendVerificationEmail(userCredential.user!);

        setState(() {
          _errorMessage =
          "Account created! Verification email sent. Please check your inbox.";
          _isLogin = true; // switch to login mode
        });
        return;
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = "An unexpected error occurred.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

// --- Centralized email verification ---
  Future<void> _sendVerificationEmail(User user) async {
    try {
      FirebaseAuth.instance.setLanguageCode('en'); // optional, fixes locale warning
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw Exception("Failed to send verification email: ${e.message}");
    } catch (e) {
      throw Exception("Failed to send verification email: $e");
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Log In' : 'Sign Up'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                _isLogin ? 'Welcome Back!' : 'Create Your Account',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 30),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _submitAuthForm,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: Text(_isLogin ? 'Log In' : 'Sign Up'),
              ),
              const SizedBox(height: 10),
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: const Text('Forgot Password?'),
                  ),
                ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _errorMessage = null;
                  });
                },
                child: Text(
                  _isLogin ? 'Need an account? Sign Up' : 'Already have an account? Log In',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;



  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  File? _image;
  final ImagePicker _picker = ImagePicker();
  Interpreter? _interpreter;
  List<String>? _labels;
  List<dynamic>? _recognitionoftheimage;
  bool _isModelLoaded = false;
  List<Map<String, dynamic>> _history = [];
  bool _isHistoryLoading = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSubscription;
  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }
  Future<String> _saveImageLocally(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'img_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final newPath = '${directory.path}/$fileName';
    final newFile = await imageFile.copy(newPath);
    return newFile.path;
  }


  String _getLikelihoodText(double confidence) {
    if (confidence >= 75.0) {
      return 'Very Likely';
    } else if (confidence >= 50.0) {
      return 'Likely';
    } else {
      return 'Less Likely';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadtheskinmodel();

    // Check and show disclaimer after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowDisclaimer();
    });

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {

      if (user != null && mounted) {
        _loadUserHistory();
      } else if (mounted) {

        setState(() {
          _history = [];
          _isHistoryLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {

    _authSubscription?.cancel();
    _interpreter?.close();
    super.dispose();
  }

  // --- START DISCLAIMER LOGIC ---

  // Helper to get the Firestore document reference for the user's disclaimer status
  // --- START DISCLAIMER LOGIC ---

// Helper to get the Firestore document reference for the user's disclaimer status
  DocumentReference _getDisclaimerDocRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Fallback for safety, though user should be authenticated here
      throw Exception("User is not authenticated. Cannot get disclaimer status.");
    }
    // Path: users/{userId}/settings/disclaimer
    return _firestore.collection('users').doc(user.uid).collection('settings').doc('disclaimer');
  }

// Checks Firestore and shows the dialog if the user hasn't acknowledged it
  Future<void> _checkAndShowDisclaimer() async {
    try {
      final doc = await _getDisclaimerDocRef().get();

      // Safely cast the data to a map and check the acknowledged status.
      final data = doc.data() as Map<String, dynamic>?;

      // If the document doesn't exist OR the 'acknowledged' field is false, show the dialog.
      // The conditional access `data?['acknowledged']` is now safe.
      if (!doc.exists || data?['acknowledged'] != true) {
        _showDisclaimerDialog();
      }
    } catch (e) {
      print("Error checking disclaimer status, showing dialog as safe default: $e");
      // Show the dialog if there's any error fetching the status to ensure the user sees it.
      if (mounted) {
        _showDisclaimerDialog();
      }
    }
  }

  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Important Disclaimer'),
          content: const Text(
            'This app is for informational purposes only. It is not a substitute for professional medical advice, diagnosis, or treatment. Always consult with a qualified healthcare professional for any health concerns or before making any decisions related to your health.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Understood'),
              onPressed: () {
                Navigator.of(context).pop();
                _acknowledgeDisclaimer();
              },
            ),
          ],
        );
      },
    );
  }

  // Sets the acknowledgment flag in Firestore
  Future<void> _acknowledgeDisclaimer() async {
    try {
      await _getDisclaimerDocRef().set(
        {'acknowledged': true, 'timestamp': Timestamp.now()},
        SetOptions(merge: true),
      );
    } catch (e) {
      print("Error saving disclaimer acknowledgment: $e");
    }
  }

  // --- END DISCLAIMER LOGIC ---

  Future<void> _loadUserHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _history = [];
      _isHistoryLoading = true;
    });

    if (user == null) {
      setState(() {
        _isHistoryLoading = false;
      });
      return;

    }

    try {
      final historySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('classifications')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _history = historySnapshot.docs.map((doc) {
          final data = doc.data();
          final timestamp = (data['timestamp'] as Timestamp).toDate();

          return {
            'image_path': data['image_path'],
            'timestamp': timestamp,
            'result': data['result'],
            'id': doc.id,
          };
        }).toList();
        _isHistoryLoading = false;
      });
    } catch (e) {
      print('Error loading history: $e');
      setState(() {
        _isHistoryLoading = false;
      });
    }
  }


  Future<void> _loadtheskinmodel() async {
    try {
      _interpreter = await Interpreter.fromAsset('FINALMODEL/model_unquant.tflite');
      _labels = await _loadLabelstxtfile();
      setState(() {
        _isModelLoaded = true;
      });
    } catch (e) {
      print('Failed to load the TFLite model or labels: $e');
      setState(() {
        _isModelLoaded = true;
      });
    }
  }


  Future<List<String>> _loadLabelstxtfile() async {
    final labelsData = await DefaultAssetBundle.of(context).loadString('FINALMODEL/labels.txt');
    final labels = labelsData.split('\n').map((label) => label.trim()).toList();

    print('Number of labels loaded: ${labels.length}');
    return labels;
  }
  // --- REPLACE your old _runInference with this one ---
  Future<void> _runInference(File imageFile) async {
    if (_interpreter == null) {
      print('Interpreter is not loaded.');
      return;
    }

    List<Map<String, dynamic>>? recognitions;

    try {
      // 1. SAVE THE IMAGE LOCALLY FIRST to get a permanent path
      final String permanentPath = await _saveImageLocally(imageFile);
      print('Saved permanent image path: $permanentPath');

      // 2. Run inference using the original file bytes
      final bytes = await imageFile.readAsBytes();

      recognitions = await compute(_inferenceIsolate, {
        'imageBytes': bytes,
        'interpreter_address': _interpreter!.address,
        'labels': _labels,
      });


      setState(() {
        _recognitionoftheimage = recognitions;
      });


      if (recognitions?.isNotEmpty == true) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final result = recognitions![0];
        final historyData = {
          'image_path': permanentPath, // <-- 3. Use the permanent path
          'timestamp': Timestamp.now(),
          'result': result,
        };

        try {
          final docRef = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('classifications')
              .add(historyData);


          if (mounted) {
            setState(() {
              final newHistoryItem = {
                'image_path': permanentPath, // <-- 4. Use the permanent path
                'timestamp': DateTime.now(),
                'result': result,
                'id': docRef.id,
              };
              _history.insert(0, newHistoryItem);

              // 5. ALSO update the main image to point to the permanent file
              _image = File(permanentPath);
            });
          }
        } catch (e) {
          print('Error saving history to Firestore: $e');
        }
      }
    } catch (e) {
      print('Error during inference: $e');
    }
  }





  static List<Map<String, dynamic>> _inferenceIsolate(Map<String, dynamic> message) {
    final Uint8List imageBytes = message['imageBytes'] as Uint8List;
    final interpreter = Interpreter.fromAddress(message['interpreter_address'] as int);
    final labels = List<String>.from(message['labels'] as List);

    try {
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return [];

      final resized = img.copyResize(originalImage, width: 224, height: 224);
      final rgba = resized.getBytes();

      final inputBytes = Float32List(224 * 224 * 3);
      for (int i = 0; i < 224 * 224; i++) {
        final r = rgba[i * 3];
        final g = rgba[i * 3 + 1];
        final b = rgba[i * 3 + 2];

        inputBytes[i * 3]     = (r / 127.5) - 1.0;
        inputBytes[i * 3 + 1] = (g / 127.5) - 1.0;
        inputBytes[i * 3 + 2] = (b / 127.5) - 1.0;
      }

      final input = inputBytes.reshape([1,224,224,3]);
      final output = List.generate(1, (_) => List.filled(labels.length, 0.0));
      interpreter.run(input, output);

      var results = output[0].map((v) => (v as num).toDouble()).toList();

      final recognitions = <Map<String,dynamic>>[];
      for (int i = 0; i < results.length; i++) {
        recognitions.add({
          'label': labels[i],
          'confidence': results[i],
        });
      }
      recognitions.sort((a,b) => b['confidence'].compareTo(a['confidence']));
      return recognitions;
    } catch (e) {
      print('Error during isolate inference: $e');
      return [];
    }
  }


  void _processSingleFile(File imageFile) {
    setState(() {
      _image = imageFile;
      _recognitionoftheimage = null;
    });
    _runInference(imageFile);
  }


  Future<void> _processMultipleFiles(List<File> imageFiles) async {

    setState(() {
      _image = null;
      _recognitionoftheimage = null;
    });


    for (final file in imageFiles) {
      setState(() {
        _image = file;
      });

      await _runInference(file);


      await Future.delayed(const Duration(milliseconds: 500));
    }

  }


  Future<void> _pickImagesFromGallery() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      await _processMultipleFiles(pickedFiles.map((xfile) => File(xfile.path)).toList());
    }
  }


  Future<void> _takeImageFromCamera() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      _processSingleFile(File(pickedFile.path));
    }
  }


  void _viewHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HistoryScreen(history: _history, likelihoodGetter: _getLikelihoodText),
      ),
    );
  }

  void _showImageSourceModal(BuildContext bottomsheet) {
    showModalBottomSheet(
      context: bottomsheet,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Gallery (Multi-Select)'),
                onTap: () {
                  _pickImagesFromGallery();
                  Navigator.of(context).pop();
                },
              ),

              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera (Single)'),
                onTap: () {
                  _takeImageFromCamera();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),

      bottomNavigationBar: BottomAppBar(
        color: Colors.black26,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.history_sharp, size: 30),
              onPressed: _viewHistory,
              color: Theme.of(context).colorScheme.primary,
            ),
            IconButton(
              icon: const Icon(Icons.add_a_photo, size: 30),
              onPressed: () => _showImageSourceModal(context),
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
      body: Center(
          child: (!_isModelLoaded || _isHistoryLoading)
              ? const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Loading app data...'),
            ],
          )
              : SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                // Removed the original inline disclaimer text here.
                const SizedBox(height: 16), // Added spacing where the disclaimer used to be.
                if (_image != null)
                  Container(
                    width: 400,
                    height: 400,
                    child: Image.file(_image!),
                  )
                else
                  const Text(
                    'No image selected.',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 20),

                if (_recognitionoftheimage != null)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Classification Results',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Divider(height: 15, thickness: 1.5),

                          ..._recognitionoftheimage!.map((result) {
                            final label = result['label'] as String;
                            final confidence = (result['confidence'] as double) * 100;
                            final likelihoodText = _getLikelihoodText(confidence);

                            Color likelihoodColor;
                            if (confidence >= 75.0) {
                              likelihoodColor = Colors.green.shade700;
                            } else if (confidence >= 50.0) {
                              likelihoodColor = Colors.orange.shade700;
                            } else {
                              likelihoodColor = Colors.red.shade700;
                            }


                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        likelihoodText,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: likelihoodColor,
                                        ),
                                      ),
                                      Text(
                                        '(${confidence.toStringAsFixed(2)}%)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          )


      ),
    );
  }
}typedef LikelihoodGetter = String Function(double confidence);

class HistoryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final LikelihoodGetter likelihoodGetter;

  const HistoryScreen({super.key, required this.history, required this.likelihoodGetter});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classification History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: history.isEmpty
          ? const Center(
        child: Text(
          'No classification history yet.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: history.length,
        itemBuilder: (context, index) {
          final item = history[index];
          final result = item['result'] as Map<String, dynamic>;
          final confidence = (result['confidence'] as double) * 100;
          final likelihoodText = likelihoodGetter(confidence);

          return ListTile(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => HistoryDetailScreen(historyItem: item, likelihoodGetter: likelihoodGetter),
                ),
              );
            },

            leading: FutureBuilder<bool>( // <--- START OF FIX
              // Check if the file exists asynchronously
              future: File(item['image_path'] as String).exists(),
              builder: (context, snapshot) {
                // If the check is done and the file exists, display the image
                if (snapshot.connectionState == ConnectionState.done && snapshot.data == true) {
                  return SizedBox(
                    width: 50,
                    height: 50,
                    // Note: We use the path from historyItem, which is a String
                    child: Image.file(
                      File(item['image_path'] as String),
                      fit: BoxFit.cover,
                      // Adding a frame builder helps handle loading phases gracefully
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (frame == null) {
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                        }
                        return child;
                      },
                    ),
                  );
                } else if (snapshot.hasError || (snapshot.connectionState == ConnectionState.done && snapshot.data == false)) {
                  // If the file is confirmed missing or an error occurred, show a fallback icon
                  return const SizedBox(
                    width: 50,
                    height: 50,
                    child: Icon(Icons.broken_image, color: Colors.red),
                  );
                }
                // While waiting for the existence check, show a loader
                return const SizedBox(
                  width: 50,
                  height: 50,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
            ),
            title: Text(
              'Predicted: ${result['label']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$likelihoodText (${confidence.toStringAsFixed(2)}%)\n'
                  'Time: ${item['timestamp'].toString().substring(0, 16)}',
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}


class HistoryDetailScreen extends StatelessWidget {
  final Map<String, dynamic> historyItem;
  final LikelihoodGetter likelihoodGetter;

  const HistoryDetailScreen({super.key, required this.historyItem, required this.likelihoodGetter});
  Future<void> _generateAndSavePdf(BuildContext context) async {
    final String imagePath = historyItem['image_path'] as String;
    final Map<String, dynamic> result = historyItem['result'] as Map<String, dynamic>;
    final double confidence = (result['confidence'] as double) * 100;
    final String label = result['label'] as String;
    final DateTime timestamp = historyItem['timestamp'] as DateTime;
    final String likelihoodText = likelihoodGetter(confidence);

    final pdf = pw.Document();
    final imageBytes = File(imagePath).readAsBytesSync();
    final pdfImage = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('Classification Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
              ),
              pw.SizedBox(height: 20),

              // Image in PDF
              pw.Center(
                child: pw.Container(
                  width: 250,
                  height: 250,
                  child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Text('Details:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),

              _buildPdfDetailRow('Prediction:', label, PdfColors.black),
              _buildPdfDetailRow('Likelihood:', likelihoodText, _getConfidenceColor(confidence)),
              _buildPdfDetailRow('Confidence Score:', '${confidence.toStringAsFixed(2)}%', PdfColors.orange700),
              _buildPdfDetailRow('Time:', timestamp.toString().substring(0, 16), PdfColors.grey700),

              pw.SizedBox(height: 50),
              pw.Text(
                '*Disclaimer: This report is for informational purposes only. Always consult with a healthcare professional.*',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.red700),
              ),
            ],
          );
        },
      ),
    );
    if (await Permission.storage.request().isGranted) {
      final output = await getTemporaryDirectory();
      final filePath = '${output.path}/Classification_Report_${timestamp.microsecondsSinceEpoch}.pdf';
      final file = File(filePath);

      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(filePath)], text: 'Classification Report from FYP Demo App');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report saved and ready to share!')),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage permission denied. Cannot save file.')),
        );
      }
    }
  }

  pw.Widget _buildPdfDetailRow(String title, String value, PdfColor valueColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 16)),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  PdfColor _getConfidenceColor(double confidence) {
    if (confidence >= 75.0) {
      return PdfColors.green700;
    } else if (confidence >= 50.0) {
      return PdfColors.orange700;
    } else {
      return PdfColors.red700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String imagePath = historyItem['image_path'] as String;
    final Map<String, dynamic> result = historyItem['result'] as Map<String, dynamic>;
    final double confidence = (result['confidence'] as double) * 100;
    final String label = result['label'] as String;
    final DateTime timestamp = historyItem['timestamp'] as DateTime;
    final String likelihoodText = likelihoodGetter(confidence);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classification Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                height: 350,
              ),
            ),

            const Text(
              'Classification Result',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const Divider(),


            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Colors.green),
              title: const Text('Prediction'),
              subtitle: Text(
                label,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.favorite_border, color: Colors.pink),
              title: const Text('Likelihood Assessment'),
              subtitle: Text(
                likelihoodText,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.percent, color: Colors.orange),
              title: const Text('Confidence Score'),
              subtitle: Text(
                '${confidence.toStringAsFixed(2)}%',
                style: const TextStyle(fontSize: 18),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.access_time, color: Colors.grey),
              title: const Text('Time of Classification'),
              subtitle: Text(
                timestamp.toString().substring(0, 16),
                style: const TextStyle(fontSize: 16),
              ),
            ),


            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Save Report as PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _generateAndSavePdf(context),
            ),
          ],
        ),
      ),
    );
  }
}
