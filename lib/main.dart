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
                child: RotatedBox(
                  quarterTurns: rotated,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6.0),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: FileImage(selectedImage!) as ImageProvider<Object>,
                      )
                    ),
                  ),
                ),
              )
        
                  :
        
              const Text('Please select an image to display'),
        
              SizedBox(height: size.height * 0.001),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  selectedImage != null

                      ?

                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
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
