import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'components/info.dart';
import 'dart:developer' as developer;

Future<List<Manga>> fetchMangaList(String searchTerm) async {
  final response = await http.get(Uri.parse(
      'https://api.mangadex.org/manga?title=$searchTerm&limit=20&offset=0')); // cambiar el offset para el orden
  if (response.statusCode == 200) {
    final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
    final List<dynamic> mangaData = jsonResponse['data'];

    final List<Manga> mangaList = await Future.wait(mangaData.map((data) async {
      final Map<String, dynamic> attributes = data['attributes'];
      final responseFile = await http.get(Uri.parse(
          'https://api.mangadex.org/cover?limit=1&manga%5B%5D=${data['id'].toString()}'));
      final coverData = jsonDecode(responseFile.body);
      String coverUrl = coverData['data'][0]['attributes']['fileName'];

      return Manga(
          id: data['id'].toString(),
          title: attributes['title']['en'],
          description: attributes['description']['en'],
          coverUrl:
              'https://uploads.mangadex.org/covers/${data['id']}/$coverUrl');
    }).toList());

    return mangaList;
  } else {
    throw Exception('Failed to load manga list');
  }
}

class Manga {
  final String id;
  final String? title;
  final String? description;
  final String? coverUrl;

  Manga(
      {required this.id,
      required this.title,
      required this.description,
      required this.coverUrl});

  factory Manga.fromJson(Map<String, dynamic> json) {
    return Manga(
        id: json['id'].toString(),
        title: json['title'],
        description: json['description'],
        coverUrl: json['coverUrl']);
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<List<Manga>> currentManga;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    currentManga = fetchMangaList('');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fetch Data Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Search'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Manga',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      setState(() {
                        currentManga = fetchMangaList(_searchController.text);
                      });
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Manga>>(
                future: currentManga,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(
                              'Manga Title: ${snapshot.data![index].title}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Manga ID: ${snapshot.data![index].id}'),
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => InfoScreen(
                                            data: snapshot.data![index].id,
                                            description: snapshot
                                                .data![index].description
                                                .toString(),
                                            cover: snapshot
                                                .data![index].coverUrl
                                                .toString()),
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    snapshot.data![index].coverUrl.toString(),
                                    width: 200.0,
                                    height: 300.0,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    );
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
