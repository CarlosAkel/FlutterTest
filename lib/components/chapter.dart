import 'dart:async';
import 'dart:convert';

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
    print('Type of jsonResponse[\'chapter\'][\'data\']: $dataType');
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

  const ChapterScreen({
    Key? key,
    required this.chapterNumber,
    required this.chapterId,
  }) : super(key: key);

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  late Future<Pages> currentPages;

  @override
  void initState() {
    super.initState();
    currentPages = fetchItems(widget.chapterId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chapter ${widget.chapterNumber}'),
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
        ],
      ),
    );
  }
}

class PageViewer extends StatelessWidget {
  final List<String> pages;
  final String hash;

  const PageViewer({Key? key, required this.pages, required this.hash})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: pages.length,
      itemBuilder: (context, index) {
        return Image.network(
          'https://uploads.mangadex.org/data/$hash/${pages[index]}',
          fit: BoxFit.contain,
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
        );
      },
    );
  }
}
