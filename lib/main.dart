import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'senobi_regular'
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final formatter = NumberFormat("#,###");
  int score = 0;
  int chain = 0;
  bool sounds = false;
  AudioCache cache = AudioCache();
  String birthSoundPath = "sounds/birth.mp3";
  void _pressStart(BuildContext context, bool endless, bool twinkle) {
    GamePage gamePage = GamePage(endlessMode: endless, twinkleMode: twinkle,);

    Navigator.push(context, PageRouteBuilder(
        pageBuilder: (BuildContext context, Animation<double> animation,
            Animation<double> secondaryAnimation) {
          return gamePage;
        },
        transitionsBuilder: (BuildContext context, Animation<double> animation,
            Animation<double> secondaryAnimation, Widget child) {
          return FadeTransition(
            opacity: Tween(begin: 0.1, end: 1.0).animate(animation),
            child: child,
          );}
    )).then((value) {
      setScore();
    });
  }

  @override
  void initState() {
    super.initState();
    setScore();
    cache.loadAll([birthSoundPath]);
  }

  void setScore() {
    Future(() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        score = (prefs.getInt('_score') ?? 0);
        chain = (prefs.getInt('_chain') ?? 0);
        sounds = (prefs.getBool('_sounds') ?? false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!sounds) {
            cache.play(birthSoundPath);
          }
          Future(() async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            setState(() {
              sounds = !sounds;
              prefs.setBool('_sounds', sounds);
            });
          });
        },
        backgroundColor: Colors.grey,
        child: sounds ? const Icon(Icons.volume_up) : const Icon(Icons.volume_off),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
                child: Stack(
                  children: [
                    Center(
                        child: Image.asset("assets/images/title.png")
                    ),
                    Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 20),
                          child: const Text('CATCH THE STAR',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 40,
                            ),
                          ),
                        )
                    ),
                  ],
                )
            ),
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(margin: const EdgeInsets.only(bottom: 20),child: Text(
                      'High Score: ${formatter.format(score)}',
                      style: const TextStyle(
                        fontSize: 20,
                      ),
                    ),),
                    Container(margin: const EdgeInsets.only(bottom: 20),child: Text(
                      'Max Chain: $chain',
                      style: const TextStyle(
                        fontSize: 20,
                      ),
                    ),),
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      child: ButtonTheme(
                          minWidth: 200.0,
                          height: 50.0,
                          child: ElevatedButton(
                            onPressed: (){
                              _pressStart(context, true, true);
                            },
                            style: ElevatedButton.styleFrom(
                              primary: Colors.amber, // background
                              onPrimary: Colors.white, // foreground
                            ),
                            child: const Text('TWINKLE MODE',style: TextStyle(color: Colors.white,fontSize: 30),),
                          )
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      child: ButtonTheme(
                          minWidth: 200.0,
                          height: 50.0,
                          child: ElevatedButton(
                            onPressed: (){
                              _pressStart(context, true, false);
                            },
                            style: ElevatedButton.styleFrom(
                              primary: Colors.blueAccent, // background
                              onPrimary: Colors.white, // foreground
                            ),
                            child: const Text('ENDLESS MODE',style: TextStyle(color: Colors.white,fontSize: 30),),
                          )
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 20, bottom: 20),
                      child: ButtonTheme(
                          minWidth: 200.0,
                          height: 50.0,
                          child: ElevatedButton(
                            onPressed: (){
                              _pressStart(context, false, false);
                            },
                            style: ElevatedButton.styleFrom(
                              primary: Colors.redAccent, // background
                              onPrimary: Colors.white, // foreground
                            ),
                            child: const Text('SCORE ATTACK!!',style: TextStyle(color: Colors.white,fontSize: 30),),
                          )
                      ),
                    )
                  ]
              ),
            ),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
