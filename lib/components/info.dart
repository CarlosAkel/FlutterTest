import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'chapter.dart';

class Chapters {
  final String id;
  final String? title;
  final String number;
  final String language;
  final String source;

  Chapters(
      {required this.id,
      required this.title,
      required this.number,
      required this.language,
      required this.source});

  factory Chapters.fromJson(Map<String, dynamic> json) {
    return Chapters(
        id: json['id'],
        title: json['name'],
        number: json['number'],
        language: json['language'],
        source: json["source"]);
  }
}

Future<List<Chapters>> fetchItems(String mangaId) async {
  final List<Chapters> mangaList = [];

  int offset = 0;
  int limit = 100;
  int totalChapters = 0;

  do {
    final response = await http.get(Uri.parse(
        'https://api.mangadex.org/manga/$mangaId/feed?limit=$limit&offset=$offset'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
      if (totalChapters == 0) {
        totalChapters = jsonResponse["total"];
      }

      final List<dynamic> mangaData = jsonResponse['data'];

      for (var data in mangaData) {
        final Map<String, dynamic> attributes = data['attributes'];
        mangaList.add(
          Chapters(
              id: data['id'].toString(),
              title: attributes['title'],
              number: attributes['chapter'] ?? "-1",
              language: attributes['translatedLanguage'] ?? "unknown",
              source: data['relationships'].firstWhere(
                  (element) => element['type'] == 'user',
                  orElse: () => null)?['id']),
        );
      }

      offset += limit;
    } else {
      throw Exception('Failed to load data');
    }
  } while (mangaList.length < totalChapters);

  return mangaList;
}

class InfoScreen extends StatefulWidget {
  final String data;
  final String description;
  final String cover;
  final String title;

  const InfoScreen({
    required this.data,
    required this.description,
    required this.cover,
    required this.title,
  });

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  late Future<List<Chapters>> currentChapters;
  String? selectedLanguage;
  List<String> languages = ['en'];

  @override
  void initState() {
    super.initState();
    currentChapters = fetchItems(widget.data);
    initializeLanguages();
  }

  // Initialize languages list
  void initializeLanguages() async {
    List<Chapters> chapters = await currentChapters;
    Set<String> uniqueLanguages = {};
    for (var chapter in chapters) {
      uniqueLanguages.add(chapter.language);
    }
    setState(() {
      languages = uniqueLanguages.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Center(
            child: Image.network(
              widget.cover,
              width: 200.0,
              height: 300.0,
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: Container(
              padding: EdgeInsets.all(10.0),
              child: Text(
                widget.description,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          DropdownButtonFormField<String>(
            value: selectedLanguage,
            onChanged: (newValue) {
              setState(() {
                selectedLanguage = newValue;
              });
            },
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Select Other Languages'),
              ),
              for (var language in languages)
                DropdownMenuItem(
                  value: language,
                  child: Text(language),
                ),
            ],
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 3.0),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: FutureBuilder<List<Chapters>>(
                future: currentChapters,
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
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No data available.'),
                    );
                  } else {
                    // Extract unique languages from fetched data
                    Set<String> uniqueLanguages = {};
                    for (var chapter in snapshot.data!) {
                      uniqueLanguages.add(chapter.language);
                    }
                    languages = uniqueLanguages.toList();

                    // Filter chapters by selected language
                    List<Chapters> filteredChapters = snapshot.data!;
                    if (selectedLanguage != null) {
                      filteredChapters = filteredChapters
                          .where(
                              (chapter) => chapter.language == selectedLanguage)
                          .toList();
                    }

                    // Sort and display filtered chapters
                    filteredChapters.sort((a, b) {
                      double aNumber = double.tryParse(a.number ?? '') ?? -1;
                      double bNumber = double.tryParse(b.number ?? '') ?? -1;

                      if (aNumber == -1 || bNumber == -1) {
                        return 0;
                      }

                      return aNumber.compareTo(bNumber);
                    });

                    return ListView.builder(
                      itemCount: filteredChapters.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChapterScreen(
                                          chapterNumber: filteredChapters[index]
                                              .number
                                              .toString(),
                                          chapterId: filteredChapters[index]
                                              .id
                                              .toString(),
                                          mangaId: widget.data.toString(),
                                          source: filteredChapters[index]
                                              .source
                                              .toString()),
                                    ),
                                  );
                                },
                                child: Text(
                                    'Chapter: ${filteredChapters[index].number} Language: ${filteredChapters[index].language}'),
                              )
                            ],
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}
