import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive_flutter/adapters.dart';

var box;

Future<void> main() async{

  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Hive.initFlutter();

  box = await Hive.openBox('user');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});


  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  File? selectedImage;
  int rotated =0;

  @override
  void initState() {
    super.initState();

    var imagePath = box.get('imagePath', defaultValue: null);

    if(imagePath != null && selectedImage == null){
      setState(() {
        selectedImage = File(imagePath);
      });
    }

  }

  @override
  Widget build(BuildContext context) {

    Size size = MediaQuery.of(context).size;

    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          toolbarHeight: 1,
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: <Widget>[

                selectedImage != null

                    ?

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: RotatedBox(
                      quarterTurns: rotated,
                      child: Image.file(selectedImage!, fit: BoxFit.contain, width: double.infinity, height: double.infinity),
                    ),
                  ),
                )

                    :

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Please select an image to display',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),

                SizedBox(height: size.height * 0.02),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    selectedImage != null

                        ?

                    Flexible(
                      child: Container(
                        margin: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1F2430),
                              elevation: 2,
                            ),
                            onPressed: () {
                              setState(() {
                                rotated--;
                              });
                            },
                            child: const Icon(Icons.rotate_left)
                        ),
                      ),
                    )
                        :
                    Container(),

                    Flexible(
                      child: Container(
                        margin: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                            ),
                            onPressed: () async{
                              PlatformFile? result = await FilePicker.pickFile(
                                  type: FileType.image
                              );

                              if (result != null) {
                                setState(() {
                                  selectedImage = File(result.path!);
                                  box.put('imagePath', selectedImage!.path);
                                });
                              }
                            },
                            child: const Icon(Icons.image)
                        ),
                      ),
                    ),

                    Flexible(
                      child: Container(
                        margin: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.redAccent,
                              elevation: 2,
                            ),
                            onPressed: () async{

                              setState(() {
                                if(selectedImage !=null){
                                  selectedImage = null;
                                  box.put('imagePath', null);
                                }
                                else{
                                  Fluttertoast.showToast(msg: 'No image saved to delete',toastLength: Toast.LENGTH_SHORT,gravity: ToastGravity.BOTTOM);
                                }
                              });

                            },
                            child: const Icon(Icons.delete_forever)
                        ),
                      ),
                    ),

                    selectedImage != null

                        ?

                    Flexible(
                      child: Container(
                        margin: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1F2430),
                              elevation: 2,
                            ),
                            onPressed: () {
                              setState(() {
                                rotated++;
                              });
                            },
                            child: const Icon(Icons.rotate_right)
                        ),
                      ),
                    )
                        :
                    Container(),

                  ],
                ),



              ],
            ),
          ),
        )
    );
  }
}