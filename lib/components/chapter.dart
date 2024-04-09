import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Pages {
  final String hash;
  final List<String> data;
  final List<String> dataSaver;

  Pages({required this.hash, required this.data, required this.dataSaver});

  factory Pages.fromJson(Map<String, dynamic> json) {
    return Pages(
      hash: json['hash'],
      data: json['data'],
      dataSaver: json['dataSaver'],
    );
  }
}

Future<Pages> fetchItems(String chapterId) async {
  final response = await http
      .get(Uri.parse('https://api.mangadex.org/at-home/server/$chapterId'));

  if (response.statusCode == 200) {
    final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
    var dataType = jsonResponse['chapter']["data"].runtimeType;
    return Pages(
      hash: jsonResponse['chapter']["hash"].toString(),
      data: jsonResponse['chapter']["data"].cast<String>(),
      dataSaver: jsonResponse['chapter']["dataSaver"].cast<String>(),
    );
  } else {
    throw Exception('Failed to load data');
  }
}

class ChapterScreen extends StatefulWidget {
  final String chapterNumber;
  final String chapterId;
  final String mangaId;
  final String source;

  const ChapterScreen({
    Key? key,
    required this.chapterNumber,
    required this.chapterId,
    required this.mangaId,
    required this.source,
  }) : super(key: key);

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  late Future<Pages> currentPages;
  String newChapterNumber = '';
  String newChapterId = '';

  @override
  void initState() {
    super.initState();
    newChapterNumber = widget.chapterNumber;
    currentPages = fetchItems(widget.chapterId);
  }

  void _loadChapter(
      BuildContext context, String chapterNumber, bool next) async {
    // We search the chapters in the language and see the next one or above
    // CHAPTER LOAD
    int offset = 0;
    int limit = 100;
    int totalChapters = 0;
    Map<String, dynamic> value;
    final response = await http.get(Uri.parse(
        'https://api.mangadex.org/manga/${widget.mangaId}/feed?limit=$limit&offset=$offset'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
      List<Map<String, dynamic>> dataList =
          (jsonResponse['data'] as List).cast<Map<String, dynamic>>();
      List<Map<String, dynamic>> names = dataList
          .where((map) => map['attributes']["translatedLanguage"] == 'en')
          .toList();

      if (next) {
        names.sort((a, b) =>
            a["attributes"]['chapter'].compareTo(b["attributes"]['chapter']));

        var result = names.where((element) =>
            (element['relationships'] as List<dynamic>).any((subElement) =>
                subElement['type'] == 'user' &&
                subElement['id'] == widget.source));
        value = result.firstWhere((element) {
          return int.parse(element["attributes"]["chapter"]) >
              int.parse(chapterNumber);
        });
      } else {
        names.sort((a, b) =>
            b["attributes"]['chapter'].compareTo(a["attributes"]['chapter']));

        var result = names.where((element) =>
            (element['relationships'] as List<dynamic>).any((subElement) =>
                subElement['type'] == 'user' &&
                subElement['id'] == widget.source));
        value = result.firstWhere((element) {
          return int.parse(element["attributes"]["chapter"]) <
              int.parse(chapterNumber);
        });
      }
    } else {
      throw Exception('Failed to load data');
    }
    setState(() {
      newChapterNumber = value["attributes"]["chapter"];
      currentPages = fetchItems(value["id"]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chapter $newChapterNumber'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<Pages>(
              future: currentPages,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasError) {
                  print('Error fetching data: ${snapshot.error}');
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                } else if (!snapshot.hasData || snapshot.data!.data.isEmpty) {
                  return const Center(
                    child: Text('No data available.'),
                  );
                } else {
                  return PageViewer(
                      pages: snapshot.data!.data, hash: snapshot.data!.hash);
                }
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  _loadChapter(context, newChapterNumber, false);
                },
                child: Text('Previous Chapter'),
              ),
              ElevatedButton(
                onPressed: () {
                  _loadChapter(context, newChapterNumber, true);
                },
                child: Text('Next Chapter'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PageViewer extends StatefulWidget {
  final List<String> pages;
  final String hash;

  const PageViewer({Key? key, required this.pages, required this.hash})
      : super(key: key);
  @override
  _PageViewerState createState() => _PageViewerState();
}

class _PageViewerState extends State<PageViewer> with TickerProviderStateMixin {
  final TransformationController viewTransformationController =
      TransformationController();
  AnimationController? _zoomAnimationController;

  @override
  void initState() {
    super.initState();
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200), // Adjust animation duration
    )
      ..addListener(() {
        // Add listener to log animation progress for debugging
        print('Animation progress: ${_zoomAnimationController!.value}');
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Add listener to log animation completion for debugging
          print('Animation completed!');
        }
      });
  }

  @override
  void dispose() {
    _zoomAnimationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Adjust this value to reduce the padding between pages
    final double viewportFraction = 1;
    final zoomFactor = 2.0;
    final xTranslate = 300.0;
    final yTranslate = 300.0;
    viewTransformationController.value.setEntry(0, 0, zoomFactor);
    viewTransformationController.value.setEntry(1, 1, zoomFactor);
    viewTransformationController.value.setEntry(2, 2, zoomFactor);
    viewTransformationController.value.setEntry(0, 3, -xTranslate);
    viewTransformationController.value.setEntry(1, 3, -yTranslate);

    final imageUrls = widget.pages
        .map((page) =>
            'https://uploads.mangadex.org/data/${widget.hash}/${page}')
        .toList();

    imageUrls.forEach((url) => precacheImage(NetworkImage(url), context));

    return PageView.builder(
      controller: PageController(
        viewportFraction: viewportFraction,
      ),
      scrollDirection: Axis.vertical,
      itemCount: widget.pages.length,
      itemBuilder: (context, index) {
        return GestureDetector(
            onDoubleTap: () {
              final currentScale =
                  viewTransformationController.value.getMaxScaleOnAxis();
              final targetScale =
                  currentScale >= 6.0 ? 2.0 : currentScale * 2.0;

              print('Target $targetScale');
              _zoomAnimationController?.reset();
              final animation = Matrix4Tween(
                begin: viewTransformationController.value,
                end: Matrix4.identity()..scale(targetScale, targetScale),
              ).animate(_zoomAnimationController!);
              _zoomAnimationController!.forward();

              viewTransformationController.value = Matrix4.identity()
                ..scale(targetScale, targetScale);
            },
            child: InteractiveViewer(
              transformationController: viewTransformationController,
              minScale: 0.1,
              maxScale: 6,
              child: Center(
                child: Container(
                  height: double.infinity,
                  width: double.infinity,
                  child: Image.network(fit: BoxFit.scaleDown, imageUrls[index]),
                ),
              ),
            ));
      },
    );
  }
}
