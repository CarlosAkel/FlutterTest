import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'chapter.dart';

class Chapters {
  final String id;
  final String? title;
  final String number;

  Chapters({required this.id, required this.title, required this.number});

  factory Chapters.fromJson(Map<String, dynamic> json) {
    return Chapters(
      id: json['id'],
      title: json['name'],
      number: json['number'],
    );
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
          ),
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

  const InfoScreen({
    required this.data,
    required this.description,
    required this.cover,
  });

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  late Future<List<Chapters>> currentChapters;

  @override
  void initState() {
    super.initState();
    currentChapters = fetchItems(widget.data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Info'),
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
                    snapshot.data!.sort((a, b) {
                      double aNumber = double.tryParse(a.number ?? '') ?? -1;
                      double bNumber = double.tryParse(b.number ?? '') ?? -1;

                      if (aNumber == -1 || bNumber == -1) {
                        return 0;
                      }

                      return aNumber.compareTo(bNumber);
                    });

                    return ListView.builder(
                      itemCount: snapshot.data!.length,
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
                                        chapterNumber: snapshot
                                            .data![index].number
                                            .toString(),
                                        chapterId:
                                            snapshot.data![index].id.toString(),
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                    'Chapter: ${snapshot.data![index].number}'),
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
