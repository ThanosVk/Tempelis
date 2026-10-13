import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';

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

  // Paths of the images, all copies stored in the app's private folder.
  List<String> imagePaths = [];

  // Rotation (in quarter turns) per image. Kept in memory only, on purpose.
  final Map<String, int> rotations = {};

  final PageController _pageController = PageController(viewportFraction: 0.88);
  int currentPage = 0;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    final saved = List<String>.from(box.get('imagePaths', defaultValue: <String>[]));

    // Drop paths whose files no longer exist.
    final existing = saved.where((p) => File(p).existsSync()).toList();
    await box.put('imagePaths', existing);

    if (!mounted) return;
    setState(() {
      imagePaths = existing;
    });
  }

  // Copies a picked image into the app's private documents folder, so it
  // doesn't depend on the picker's temporary cache. The folder is removed
  // together with the app when it is uninstalled.
  Future<String> _copyToAppStorage(String sourcePath, int index) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${docsDir.path}/images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // Grab the extension (".jpg", ".png"...) from the original path.
    final dot = sourcePath.lastIndexOf('.');
    final slash = sourcePath.lastIndexOf(RegExp(r'[\\/]'));
    final extension = dot > slash ? sourcePath.substring(dot) : '';

    // The new name is a timestamp + index, so every copy is unique.
    final newPath = '${imagesDir.path}/${DateTime.now().microsecondsSinceEpoch}_$index$extension';
    await File(sourcePath).copy(newPath);
    return newPath;
  }

  Future<void> _savePaths() async {
    await box.put('imagePaths', List<String>.from(imagePaths));
  }

  Future<void> _pickImages() async {
    if (_adding) return;

    final List<PlatformFile> files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;

    setState(() {
      _adding = true;
    });

    final added = <String>[];
    try {
      for (final file in files) {
        final path = file.path;
        if (path == null) continue;
        added.add(await _copyToAppStorage(path, added.length));
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Could not save some of the images',toastLength: Toast.LENGTH_SHORT,gravity: ToastGravity.BOTTOM);
    }

    if (!mounted) return;

    final firstNewIndex = imagePaths.length;
    setState(() {
      imagePaths.addAll(added);
      _adding = false;
    });
    await _savePaths();

    // Show the first of the newly added images.
    if (added.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            firstNewIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _deleteCurrentImage() async {
    final index = currentPage;

    if (index >= imagePaths.length) {
      Fluttertoast.showToast(msg: 'No image saved to delete',toastLength: Toast.LENGTH_SHORT,gravity: ToastGravity.BOTTOM);
      return;
    }

    final path = imagePaths[index];

    // Deleting the last photo steps back to the previous one, otherwise the
    // next photo slides into the same position.
    final isLastPhoto = index == imagePaths.length - 1;
    final newPage = (isLastPhoto && index > 0) ? index - 1 : index;
    if (newPage != index) {
      _pageController.jumpToPage(newPage);
    }

    setState(() {
      imagePaths.removeAt(index);
      rotations.remove(path);
      currentPage = newPage;
    });
    await _savePaths();

    try {
      await File(path).delete();
    } catch (_) {}
  }

  // Opens the photo in fullscreen. Double tap on the fullscreen page (or the
  // system back button) closes it again.
  Future<void> _openFullscreen(String path) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: _FullscreenImage(
            path: path,
            quarterTurns: rotations[path] ?? 0,
          ),
        ),
      ),
    );

    // Back from fullscreen: bring the status/navigation bars back.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Widget _buildImageCard(String path) {
    return GestureDetector(
      key: ValueKey(path),
      onDoubleTap: () => _openFullscreen(path),
      child: _buildImageCardBody(path),
    );
  }

  Widget _buildImageCardBody(String path) {
    return Card(
      color: Colors.white,
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: RotatedBox(
          quarterTurns: rotations[path] ?? 0,
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.broken_image_outlined, size: 48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddCard() {
    return Card(
      color: Colors.white,
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: _pickImages,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                imagePaths.isEmpty
                    ? 'Please select an image to display'
                    : 'Add more images',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // One dot per photo, plus one for the "+" page. The current page is
  // shown as a longer, colored dot.
  Widget _buildDots() {
    final total = imagePaths.length + 1;
    final primary = Theme.of(context).colorScheme.primary;

    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 6,
      children: List.generate(total, (i) {
        final active = i == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? primary : Colors.grey[400],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {

    Size size = MediaQuery.of(context).size;

    // True when the page on screen is a photo (and not the "+" card).
    final bool onPhoto = currentPage < imagePaths.length;

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

                if (_adding) const LinearProgressIndicator(),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: imagePaths.length + 1,
                    onPageChanged: (page) {
                      setState(() {
                        currentPage = page;
                      });
                    },
                    itemBuilder: (context, index) {
                      if (index == imagePaths.length) {
                        return _buildAddCard();
                      }
                      return _buildImageCard(imagePaths[index]);
                    },
                  ),
                ),

                SizedBox(height: size.height * 0.015),

                _buildDots(),

                SizedBox(height: size.height * 0.005),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    onPhoto

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
                                final path = imagePaths[currentPage];
                                rotations[path] = (rotations[path] ?? 0) - 1;
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
                            onPressed: _pickImages,
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
                            onPressed: _deleteCurrentImage,
                            child: const Icon(Icons.delete_forever)
                        ),
                      ),
                    ),

                    onPhoto

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
                                final path = imagePaths[currentPage];
                                rotations[path] = (rotations[path] ?? 0) + 1;
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

// Fullscreen viewer: black background, pinch to zoom, double tap to close.
class _FullscreenImage extends StatelessWidget {
  final String path;
  final int quarterTurns;

  const _FullscreenImage({required this.path, required this.quarterTurns});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => Navigator.of(context).pop(),
        child: SizedBox.expand(
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: RotatedBox(
              quarterTurns: quarterTurns,
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      size: 48, color: Colors.white54),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}