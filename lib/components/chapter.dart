import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:hidable/hidable.dart';

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
  final ScrollController _scrollController = ScrollController();
  String newChapterNumber = '';
  String newChapterId = '';

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }

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
      List<Map<String, dynamic>> names = dataList.toList();

      if (next) {
        names.sort((a, b) => double.parse(a["attributes"]['chapter'])
            .compareTo(double.parse(b["attributes"]['chapter'])));
        var result = names.where((element) =>
            (element['relationships'] as List<dynamic>).any((subElement) =>
                subElement['type'] == 'user' &&
                subElement['id'] == widget.source));
        value = result.firstWhere((element) {
          return double.parse(element["attributes"]["chapter"]) >
              double.parse(chapterNumber);
        });
      } else {
        names.sort((a, b) => double.parse(b["attributes"]['chapter'])
            .compareTo(double.parse(a["attributes"]['chapter'])));

        var result = names.where((element) =>
            (element['relationships'] as List<dynamic>).any((subElement) =>
                subElement['type'] == 'user' &&
                subElement['id'] == widget.source));
        value = result.firstWhere((element) {
          return double.parse(element["attributes"]["chapter"]) <
              double.parse(chapterNumber);
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
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('Chapter $newChapterNumber'),
              IconButton(
                icon: Icon(
                  Icons.arrow_left,
                  color: Colors.black,
                  size: 50.0,
                ),
                onPressed: () {
                  _loadChapter(context, newChapterNumber, false);
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_right,
                  color: Colors.black,
                  size: 50.0,
                ),
                onPressed: () {
                  _loadChapter(context, newChapterNumber, true);
                },
              ),
            ],
          ),
        ),
        body: Column(children: [
          FutureBuilder<Pages>(
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
                return Expanded(
                    child: PageViewer(
                        pages: snapshot.data!.data, hash: snapshot.data!.hash));
              }
            },
          ),
        ]));
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

class _PageViewerState extends State<PageViewer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = widget.pages
        .map((page) => 'https://uploads.mangadex.org/data/${widget.hash}/$page')
        .toList();
    imageUrls.forEach((url) => precacheImage(NetworkImage(url), context));
    return PhotoViewGallery.builder(
      itemCount: widget.pages.length,
      scrollDirection: Axis.vertical,
      builder: (context, index) {
        final imageProvider = NetworkImage(imageUrls[index]);
        return PhotoViewGalleryPageOptions(
          imageProvider: imageProvider,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          basePosition: Alignment.center,
          // Set the initial scale based on screen width and desired image width
          initialScale: PhotoViewComputedScale.contained,
          heroAttributes: PhotoViewHeroAttributes(tag: imageUrls[index]),
        );
      },
      loadingBuilder: (context, event) {
        num totalBytes = event?.expectedTotalBytes ?? 0;
        return Center(
          child: Container(
            width: 20.0,
            height: 20.0,
            child: CircularProgressIndicator(
              value:
                  event == null ? 0 : event.cumulativeBytesLoaded / totalBytes,
            ),
          ),
        );
      },
      backgroundDecoration: BoxDecoration(color: Colors.black),
      pageController: PageController(),
    );
  }
}
