import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:change_case/change_case.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(snapshot.error.toString(),
                      textDirection: TextDirection.ltr)));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return const MyApp();
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthNotifier(),
      child: MaterialApp(
        title: 'Startup Name Generator',
        theme: ThemeData(
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepPurple,
          ),
          listTileTheme: const ListTileThemeData(
            textColor: Colors.black,
          ),
        ),
        home: const RandomWords(),
      )
    );
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  State<RandomWords> createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _locallySaved = <WordPair>{};
  final _remotelySaved = <String>{};
  final _biggerFont = const TextStyle(fontSize: 18);

  final SnappingSheetController snappingSheetController = SnappingSheetController();

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  ImageProvider<Object>? _profile_image;

  double _blurity = 0.0;

  Future<bool> _addUser(String? uid, String email) async {
    try {
      await _firestore.collection('users')
            .doc(uid).set({
              'email': email,
              'saved_suggestions': []
        });
      return true;
    }
    catch (e) {
      return false;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>>? _getUser() async {
      return _firestore.collection('users')
          .doc(context.read<AuthNotifier>()
          .getUid())
          .get();
  }

  Future<bool> _addSuggestionsToUser(Set<String> suggestions) async {
    try {
      _firestore.collection('users')
          .doc(context.read<AuthNotifier>()
          .getUid())
          .update(
          {'saved_suggestions': FieldValue.arrayUnion([...suggestions])});
    }
    catch(e){
      return false;
    }
    return true;
  }

  Future<bool> _removeUserSuggestion(String suggestion) async {
    var user = await _getUser();
    List userSaved = user?.get('saved_suggestions');
    userSaved.removeWhere((str){
      return str == suggestion;
    });
    if (!mounted) return false;
    try {
      _firestore.collection('users')
          .doc(context.read<AuthNotifier>()
          .getUid())
          .update({'saved_suggestions': userSaved});
    }
    catch(e){
      return false;
    }
    return true;
  }

  Future _syncLocalAndRemote() async {
    try {
      var strSaved = _locallySaved.map((v) {
        _remotelySaved.add(v.asPascalCase);
        return v.asPascalCase;
      }).toSet();
      var user = await _getUser();
      user?.data()?["saved_suggestions"].toSet().forEach( (v) {
        _remotelySaved.add(v);
        var words = v.toString().toNoCase().split(' ');
        var pair = WordPair(words[0], words[1]);
        if (_suggestions.contains(pair)){
          _locallySaved.add(pair);
        }
      }

      );
      _addSuggestionsToUser(strSaved);
    }
    catch(e){
      return;
    }
  }

  void _login() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) {
      final emailController = TextEditingController();
      final passwordController = TextEditingController();
      final confirmPasswordController = TextEditingController();
      final RoundedLoadingButtonController loginBtnController = RoundedLoadingButtonController();
      final RoundedLoadingButtonController signUpBtnController = RoundedLoadingButtonController();
      final RoundedLoadingButtonController confirmPasswordBtnController = RoundedLoadingButtonController();

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Login Page"),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Text(
                    "Welcome to Startup Names Generator, please log in!",
                  )
              ), // title
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Email',
                  ),
                  controller: emailController,
                ),
              ), // email
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Password',
                    ),
                    controller: passwordController,
                    obscureText: true,
                ),
              ), //password
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: RoundedLoadingButton(
                  controller: loginBtnController,
                  onPressed: () async {
                    var authRes = await context.read<AuthNotifier>().signIn(emailController.text, passwordController.text);
                    try {
                      String? imageUrl = await _storage.ref('profile_images')
                          .child(context.read<AuthNotifier>().getUid() ?? '')
                          .getDownloadURL();
                      if (authRes) {
                        await _syncLocalAndRemote();
                        setState(() {
                          _profile_image = imageUrl != null ?
                            NetworkImage(imageUrl) : null;
                          loginBtnController.reset();
                          Navigator.of(context).pop(); // pop of login page
                        });
                      }
                      else {
                        loginBtnController.reset();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'There was an error logging into the app')));
                      }
                    }
                    on Exception catch(e){
                      _profile_image = null;
                      loginBtnController.reset();
                      Navigator.of(context).pop();
                    }
                  },
                  color: Colors.deepPurple,
                  child: const Text('Login'),
                ),
              ) ,// login button
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: RoundedLoadingButton(
                  controller: signUpBtnController,
                  color: Colors.blueAccent,
                  onPressed: () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      builder: (context) {
                        bool notMatch = false;
                        return StatefulBuilder(
                            builder: (BuildContext context, StateSetter setState) {
                              return Container(
                                  color: Colors.white,
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10.0),
                                        child: const Text("Please confirm your password below"),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(10.0),
                                        child: TextField(
                                          decoration: InputDecoration(
                                              border: const OutlineInputBorder(),
                                              labelText: 'Password',
                                              errorText: notMatch ? "Passwords must match" : null
                                          ),
                                          controller: confirmPasswordController,
                                          obscureText: true,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(10.0),
                                        child: RoundedLoadingButton(
                                          controller: confirmPasswordBtnController,
                                          onPressed: () async {
                                            if (confirmPasswordController.text != passwordController.text){
                                              setState( ()=>notMatch=true);
                                              confirmPasswordBtnController.reset();
                                            }
                                            else {
                                              var user = await context.read<
                                                  AuthNotifier>().signUp(
                                                    emailController.text,
                                                    passwordController.text);
                                              if (user != null) {
                                                await _addUser(
                                                    user.user?.uid.characters.string,
                                                    emailController.text);
                                                await _syncLocalAndRemote();
                                                if (!mounted) return;
                                                Navigator.of(context).pop();
                                              }
                                              else {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'There was an error signing in into the app')));
                                              }
                                              if (!mounted) return;
                                              Navigator.of(context).pop();
                                            }
                                            confirmPasswordBtnController.reset();
                                          },
                                          color: Colors.blueAccent,
                                          child: const Text('Confirm'),
                                        ),
                                      ),
                                    ],
                                  )
                              );
                            }
                        );
                      }
                    );
                    signUpBtnController.reset();
                  },
                  child: const Text('New user? Click to sign up'),
                ),
              ) ,// signup button
            ],
          ),
        ),
      );
    }));
  }

  void _signOut() {
    context.read<AuthNotifier>().signOut();
    _remotelySaved.clear();
    _profile_image = null;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Successfully logged out')));
  }

  void _pushSaved() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) {
        Set<dynamic> saved = context.read<AuthNotifier>().isAuthenticated()?
        _remotelySaved
            : _locallySaved.map((e) => e.asPascalCase).toSet();
        final tiles = saved.map(
              (pair) {
            return Dismissible(
              background: Container(
                  padding: const EdgeInsets.only(right: 20.0),
                  color: Colors.deepPurple,
                  child: Row(
                    children: const [
                      IconButton(
                        icon: Icon(Icons.delete),
                        color: Colors.white,
                        onPressed: null,
                        tooltip: 'Saved Suggestions',
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Delete Suggestion',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontStyle: FontStyle.normal,
                            )
                        ),
                      ),
                    ],
                  )

              ),
              key: ValueKey<String>(pair),
              confirmDismiss: (DismissDirection direction)  {
                return showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text("Delete Suggestion"),
                      content: Text("Are you sure you want to delete $pair from your saved suggestions?"),
                      actions: [
                        TextButton(
                          child: const Text("Yes"),
                          onPressed: () {
                            setState(() {
                              var words = pair.toString().toNoCase().split(' ');
                              _locallySaved.remove(WordPair(words[0], words[1]));
                            });
                            if(context.read<AuthNotifier>().isAuthenticated()){
                              _remotelySaved.remove(pair);
                              _removeUserSuggestion(pair);
                            }
                            Navigator.of(context).pop(true);
                          },
                        ), // "Yes" button
                        TextButton(
                          child: const Text("No"),
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                        ), // "No" button
                      ],
                    );
                  },
                );
              },
              child: ListTile(
                title: Text(
                  pair,
                  style: _biggerFont,
                ),
              ),
            );
          },
        );
        final divided = tiles.isNotEmpty
            ? ListTile.divideTiles(
          context: context,
          tiles: tiles,
        ).toList()
            : <Widget>[];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Saved Suggestions'),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: ListView(
              children: divided
          ),
        );
      },
    ));
  }

  @override
  Widget build (BuildContext context) {
    context.watch<AuthNotifier>().status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Name Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            color: Colors.white,
            onPressed: (){
              _pushSaved();
            },
            tooltip: 'Saved Suggestions',
          ),
          IconButton(
            icon: context.read<AuthNotifier>().isAuthenticated() ?
            const Icon(Icons.exit_to_app) :
            const Icon(Icons.login),
            color: Colors.white,
            onPressed: context.read<AuthNotifier>().isAuthenticated() ?
            _signOut :
            _login,
            tooltip: 'Login page',
          ),
        ],
      ),
      body: context.read<AuthNotifier>().isAuthenticated() ?
        SnappingSheet(
          onSheetMoved: (position) {
            setState(() =>_blurity = position.relativeToSnappingPositions * 10);
          },
          lockOverflowDrag: true,
          controller: snappingSheetController,
          snappingPositions: const [
            SnappingPosition.factor(positionFactor: 0.0,
            grabbingContentOffset: GrabbingContentOffset.top),
            SnappingPosition.factor(positionFactor: 0.25),
            SnappingPosition.factor(positionFactor: 0.65),
            SnappingPosition.factor(positionFactor: 1.0,
            grabbingContentOffset: GrabbingContentOffset.bottom)
          ],
          grabbingHeight: 60,
          grabbing: GestureDetector(
            onTap: () {
              if (snappingSheetController.isAttached) {
                if (snappingSheetController.currentSnappingPosition == const SnappingPosition.factor(positionFactor: 0.25)){
                  snappingSheetController.snapToPosition(
                      const SnappingPosition.factor(positionFactor: 0.0,
                          grabbingContentOffset: GrabbingContentOffset.top)
                  );
                }
                else {
                  snappingSheetController.snapToPosition(
                      const SnappingPosition.factor(positionFactor: 0.25));
                }
              }
            },
            child: Container(
              color: Colors.grey,
              height: 10.0,
              child: ListTile(
                  title: Text(
                    "Welcome back, ${context.read<AuthNotifier>().getEmail()}",
                  ),
                  trailing: const Icon(Icons.keyboard_arrow_up)
              ),
            ),
          ),
          sheetBelow: SnappingSheetContent(
            draggable: true,
            child: UserProfile(localProfileImage: _profile_image, storageInstance: _storage),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
                ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemBuilder: (context, i) {
                  if (i.isOdd) return const Divider();

                  final index = i ~/ 2;
                  if (index >= _suggestions.length) {
                    _suggestions.addAll(generateWordPairs().take(10));
                  }
                  final alreadySaved = _locallySaved.contains(_suggestions[index]) ||
                      _remotelySaved.contains(_suggestions[index].asPascalCase);
                  return ListTile(
                    title: Text(
                      _suggestions[index].asPascalCase,
                      style: _biggerFont,
                    ),
                    trailing: Icon(
                      alreadySaved ? Icons.favorite : Icons.favorite_border,
                      color: alreadySaved ? Colors.red : null,
                      semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
                    ),
                    onTap: () {
                      setState(() {
                        if (alreadySaved) {
                          _locallySaved.remove(_suggestions[index]);
                          if(context.read<AuthNotifier>().isAuthenticated()) {
                            _remotelySaved.remove(_suggestions[index].asPascalCase);
                            _removeUserSuggestion(_suggestions[index].asPascalCase);
                          }
                        } else {
                          _locallySaved.add(_suggestions[index]);
                          if(context.read<AuthNotifier>().isAuthenticated()) {
                            _remotelySaved.add(_suggestions[index].asPascalCase);
                            _addSuggestionsToUser({_suggestions[index].asPascalCase});
                          }
                        }
                      });
                    },
                  );
                }, // callback for item builder
              ),
              ] +
              (_blurity>0 ?
                <Widget>[BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: _blurity,
                sigmaY: _blurity,
              ),
              child: Container(
                color: Colors.transparent,
              ),
            )]:
                <Widget>[]),
          ),
        ):
        ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemBuilder: (context, i) {
          if (i.isOdd) return const Divider();

          final index = i ~/ 2;
          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10));
          }
          final alreadySaved = _locallySaved.contains(_suggestions[index]) ||
              _remotelySaved.contains(_suggestions[index].asPascalCase);
          return ListTile(
            title: Text(
              _suggestions[index].asPascalCase,
              style: _biggerFont,
            ),
            trailing: Icon(
              alreadySaved ? Icons.favorite : Icons.favorite_border,
              color: alreadySaved ? Colors.red : null,
              semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
            ),
            onTap: () {
              setState(() {
                if (alreadySaved) {
                  _locallySaved.remove(_suggestions[index]);
                  if(context.read<AuthNotifier>().isAuthenticated()) {
                    _remotelySaved.remove(_suggestions[index].asPascalCase);
                    _removeUserSuggestion(_suggestions[index].asPascalCase);
                  }
                } else {
                  _locallySaved.add(_suggestions[index]);
                  if(context.read<AuthNotifier>().isAuthenticated()) {
                    _remotelySaved.add(_suggestions[index].asPascalCase);
                    _addSuggestionsToUser({_suggestions[index].asPascalCase});
                  }
                }
              });
            },
          );
        }, // callback for item builder
      ),
    );
  }
}

class UserProfile extends StatefulWidget {
  ImageProvider<Object>? localProfileImage;
  final FirebaseStorage? storageInstance;

  UserProfile({Key? key, this.localProfileImage, this.storageInstance}) : super(key: key);

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {

  Future<void>? uploadFile(File file, String cloudPath) {
    var fileRef = widget.storageInstance?.ref(cloudPath);
    try {
      fileRef?.putFile(file);
    }
    catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(20.0),
        color: Colors.white,
        child: ListTile(
          leading: widget.localProfileImage != null ?
            CircleAvatar(
              radius: 38,
              backgroundImage: widget.localProfileImage,
            ):
            null,
          title: Text(
            context.read<AuthNotifier>().getEmail(),
            style: const TextStyle(
              fontSize: 23.0,
            ),
          ),
          subtitle: Container(
              padding: const EdgeInsets.fromLTRB(0, 10, 90, 0),
              child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  onPressed: () async {
                    FilePickerResult? result = await FilePicker.platform.pickFiles();

                    if (result != null) {
                      var imageFile = File(result.files.single.path??'');
                      setState(() {
                        Image? image = Image.file(imageFile);
                        widget.localProfileImage = image.image;
                      });
                      await uploadFile(imageFile, "profile_images/${context.read<AuthNotifier>().getUid()??''}");
                    } else {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('No image selected')));
                    }
                  },
                  child: const Text(
                    "Change Avatar",
                    style: TextStyle(
                      fontSize: 17.0,
                      color: Colors.white,
                    ),)
              )
          ),

        )
    );
  }
}
