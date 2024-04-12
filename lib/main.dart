import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'components/info.dart';
import 'components/test.dart';
import 'package:easy_search_bar/easy_search_bar.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

Future<List<Manga>> fetchMangaList(
    String searchTerm, int page, int pageSize) async {
  final response = await http.get(Uri.parse(
      'https://api.mangadex.org/manga?title=$searchTerm&limit=$pageSize&offset=${page * pageSize}&availableTranslatedLanguage[]=en')); // cambiar el offset para el orden
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
  final TextEditingController _searchController = TextEditingController();
  final _pagingController = PagingController<int, Manga>(firstPageKey: -1);

  @override
  void initState() {
    super.initState();
    // Initial fetch with page 0 and size 20
    _pagingController.addPageRequestListener((page) {
      if (page == -1) {
        fetchMangaList(
                _searchController.text, 0, 10) // Fetch more data on scroll
            .then((fetchedManga) =>
                {_pagingController.appendPage(fetchedManga, page + 1)});
      } else {
        fetchMangaList(
                _searchController.text, page, 10) // Fetch more data on scroll
            .then((fetchedManga) =>
                {_pagingController.appendPage(fetchedManga, page + 1)});
      }
    });
  }

  void _handleSubmitted(String text) {
    _pagingController.refresh();
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
                onSubmitted: _handleSubmitted,
                onChanged: (value) {
                  setState(() {
                    // Filter suggestions based on the input value
                    // La pagina te bota por muchos requests
                    //currentManga = fetchMangaList(value);
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Search Manga',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      setState(() {
                        _pagingController.refresh();
                      });
                    },
                  ),
                ),
              ),
            ),
            Expanded(
                child: PagedListView<int, Manga>(
              pagingController: _pagingController,
              builderDelegate: PagedChildBuilderDelegate<Manga>(
                itemBuilder: (context, item, index) {
                  // Replace this with your actual widget for displaying Manga data
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InfoScreen(
                            data: item.id,
                            title: item.title.toString(),
                            description: item.description.toString(),
                            cover: item.coverUrl.toString(),
                          ),
                        ),
                      );
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.black,
                          width: 2.0, // Adjust color and width
                        ),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Image.network(
                              item.coverUrl.toString(),
                              width: 150.0, // Set a fixed width for the image
                              height: 350.0,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 1.0),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(
                                  16.0), // Adjust padding values as needed
                              child: Column(
                                children: [
                                  Text('${item.title}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Container(
                                    // Wrap description with a container
                                    width:
                                        200.0, // Set the maximum width for the text
                                    child: Text(
                                      '${item.description}',
                                      maxLines: 10,
                                      overflow: TextOverflow
                                          .ellipsis, // Allow up to 2 lines
                                      style: const TextStyle(
                                          fontSize:
                                              14.0), // Adjust font size as needed
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class MangaWidget extends StatefulWidget {
  @override
  _MangaWidgetState createState() => _MangaWidgetState();
}

class _MangaWidgetState extends State<MangaWidget> {
  String searchValue = '';
  final List<String> _suggestions = [
    'Afeganistan',
    'Albania',
    'Algeria',
    'Australia',
    'Brazil',
    'German',
    'Madagascar',
    'Mozambique',
    'Portugal',
    'Zambia'
  ];

  Future<List<String>> _fetchSuggestions(String searchValue) async {
    await Future.delayed(const Duration(milliseconds: 750));

    return _suggestions.where((element) {
      return element.toLowerCase().contains(searchValue.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Example',
        theme: ThemeData(primarySwatch: Colors.orange),
        home: Scaffold(
            appBar: EasySearchBar(
                title: const Text('Example'),
                onSearch: (value) => setState(() => searchValue = value),
                actions: [
                  IconButton(icon: const Icon(Icons.person), onPressed: () {})
                ],
                asyncSuggestions: (value) async =>
                    await _fetchSuggestions(value)),
            drawer: Drawer(
                child: ListView(padding: EdgeInsets.zero, children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue,
                ),
                child: Text('Drawer Header'),
              ),
              ListTile(
                  title: const Text('Item 1'),
                  onTap: () => Navigator.pop(context)),
              ListTile(
                  title: const Text('Item 2'),
                  onTap: () => Navigator.pop(context))
            ])),
            body: Center(child: Text('Value: $searchValue'))));
  }
}
