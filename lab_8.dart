import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';


// MAIN

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(
    themeIsDark: prefs.getBool('darkMode') ?? false,
    fontSize: prefs.getDouble('fontSize') ?? 16.0,
  ));
}


// ROOT APP WIDGET

class MyApp extends StatefulWidget {
  final bool themeIsDark;
  final double fontSize;

  const MyApp({required this.themeIsDark, required this.fontSize});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool darkMode;
  late double fontSize;

  @override
  void initState() {
    super.initState();
    darkMode = widget.themeIsDark;
    fontSize = widget.fontSize;
  }

  Future<void> updateTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    setState(() => darkMode = value);
  }

  Future<void> updateFontSize(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', value);
    setState(() => fontSize = value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Persisting Data Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: darkMode ? Brightness.dark : Brightness.light,
        textTheme: Theme.of(context).textTheme.apply(
              fontSizeFactor: fontSize / 16.0,
            ),
      ),
      home: HomeScreen(
        darkMode: darkMode,
        fontSize: fontSize,
        onThemeChanged: updateTheme,
        onFontSizeChanged: updateFontSize,
      ),
    );
  }
}


// HOME SCREEN WITH TABS

class HomeScreen extends StatefulWidget {
  final bool darkMode;
  final double fontSize;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<double> onFontSizeChanged;

  const HomeScreen({
    required this.darkMode,
    required this.fontSize,
    required this.onThemeChanged,
    required this.onFontSizeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Persisting Data Lab'),
        bottom: TabBar(
          controller: controller,
          isScrollable: true,
          tabs: const [
            Tab(text: 'SharedPrefs'),
            Tab(text: 'Counter'),
            Tab(text: 'SQLite'),
            Tab(text: 'File'),
            Tab(text: 'Hybrid'),
          ],
        ),
      ),
      body: TabBarView(
        controller: controller,
        children: [
          SharedPrefsScreen(),
          CounterScreen(),
          NotesScreen(),
          FileStorageScreen(),
          HybridScreen(
            darkMode: widget.darkMode,
            fontSize: widget.fontSize,
            onThemeChanged: widget.onThemeChanged,
            onFontSizeChanged: widget.onFontSizeChanged,
          ),
        ],
      ),
    );
  }
}


// SHARED PREFS SCREEN

class SharedPrefsScreen extends StatefulWidget {
  @override
  State<SharedPrefsScreen> createState() => _SharedPrefsScreenState();
}

class _SharedPrefsScreenState extends State<SharedPrefsScreen> {
  final TextEditingController controller = TextEditingController();
  String username = "";

  @override
  void initState() {
    super.initState();
    loadUsername();
  }

  Future<void> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username') ?? '';
    controller.text = username;
    setState(() {});
  }

  Future<void> saveUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', controller.text);
    setState(() => username = controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(controller: controller, decoration: const InputDecoration(labelText: 'Username')),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: saveUsername, child: const Text("Save")),
          const SizedBox(height: 20),
          Text("Saved username: $username"),
        ],
      ),
    );
  }
}


// COUNTER SCREEN

class CounterScreen extends StatefulWidget {
  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int count = 0;

  @override
  void initState() {
    super.initState();
    loadCounter();
  }

  Future<void> loadCounter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => count = prefs.getInt('counter') ?? 0);
  }

  Future<void> updateCounter(int newCount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('counter', newCount);
    setState(() => count = newCount);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Counter: $count', style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 12),
        Row(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton(onPressed: () => updateCounter(count + 1), child: const Text('+')),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: () => updateCounter(count - 1), child: const Text('-')),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: () => updateCounter(0), child: const Text('Reset')),
        ])
      ]),
    );
  }
}


// DATABASE MODELS

class Note {
  int? id;
  String title;
  String content;

  Note({this.id, required this.title, required this.content});

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'content': content};

  factory Note.fromMap(Map<String, dynamic> m) {
    return Note(
      id: m['id'] as int?,
      title: m['title'],
      content: m['content'],
    );
  }
}


// SQLITE HELPER

class DBHelper {
  static final DBHelper instance = DBHelper._internal();
  factory DBHelper() => instance;
  DBHelper._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'notes.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE notes (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, content TEXT)');
      },
    );
    return _db!;
  }

  Future<int> insert(Note n) async =>
      (await db).insert('notes', n.toMap());

  Future<int> update(Note n) async =>
      (await db).update("notes", n.toMap(), where: "id = ?", whereArgs: [n.id]);

  Future<int> delete(int id) async =>
      (await db).delete("notes", where: "id = ?", whereArgs: [id]);

  Future<List<Note>> getAll() async {
    final res = await (await db).query("notes", orderBy: "id DESC");
    return res.map((e) => Note.fromMap(e)).toList();
  }
}

// NOTES 

class NotesScreen extends StatefulWidget {
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final DBHelper db = DBHelper();
  List<Note> notes = [];

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  Future<void> loadNotes() async {
    notes = await db.getAll();
    setState(() {});
  }

  Future<void> editNoteDialog([Note? note]) async {
    final titleCtrl = TextEditingController(text: note?.title ?? "");
    final contentCtrl = TextEditingController(text: note?.content ?? "");

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(note == null ? "Add Note" : "Edit Note"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title")),
            TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: "Content")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Save")),
        ],
      ),
    );

    if (shouldSave ?? false) {
      if (note == null) {
        await db.insert(Note(title: titleCtrl.text, content: contentCtrl.text));
      } else {
        note.title = titleCtrl.text;
        note.content = contentCtrl.text;
        await db.update(note);
      }
      await loadNotes();
    }
  }

  Future<void> deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete?"),
        content: Text('Delete "${note.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
        ],
      ),
    );

    if (confirmed ?? false) {
      await db.delete(note.id!);
      await loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          ElevatedButton(onPressed: () => editNoteDialog(), child: const Text("Add Note")),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: loadNotes, child: const Text("Refresh")),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: notes.length,
          itemBuilder: (_, i) {
            final n = notes[i];
            return ListTile(
              title: Text(n.title),
              subtitle: Text(n.content),
              onTap: () => editNoteDialog(n),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => deleteNote(n),
              ),
            );
          },
        ),
      )
    ]);
  }
}


// FILE STORAGE SCREEN

class FileStorageScreen extends StatefulWidget {
  @override
  State<FileStorageScreen> createState() => _FileStorageScreenState();
}

class _FileStorageScreenState extends State<FileStorageScreen> {
  String fileContent = "";

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, "user_data.txt"));
  }

  Future<void> writeFile() async {
    final file = await _file();
    await file.writeAsString("Saved at: ${DateTime.now()}");
    await readFile();
  }

  Future<void> readFile() async {
    try {
      final file = await _file();
      fileContent = await file.readAsString();
    } catch (_) {
      fileContent = "No file found";
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    readFile();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        ElevatedButton(onPressed: writeFile, child: const Text("Write file")),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: readFile, child: const Text("Read file")),
        const SizedBox(height: 12),
        const Text("File content:"),
        const SizedBox(height: 8),
        SelectableText(fileContent),
      ]),
    );
  }
}


// HYBRID SCREEN 

class HybridScreen extends StatefulWidget {
  final bool darkMode;
  final double fontSize;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<double> onFontSizeChanged;

  const HybridScreen({
    required this.darkMode,
    required this.fontSize,
    required this.onThemeChanged,
    required this.onFontSizeChanged,
  });

  @override
  State<HybridScreen> createState() => _HybridScreenState();
}

class _HybridScreenState extends State<HybridScreen> {
  late bool darkMode;
  late double fontSize;
  final DBHelper db = DBHelper();
  List<Note> notes = [];

  @override
  void initState() {
    super.initState();
    darkMode = widget.darkMode;
    fontSize = widget.fontSize;
    loadNotes();
  }

  Future<void> loadNotes() async {
    notes = await db.getAll();
    setState(() {});
  }

  Future<void> addNote() async {
    await db.insert(Note(
      title: "Hybrid ${DateTime.now().millisecondsSinceEpoch}",
      content: "From Hybrid",
    ));
    await loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          const Text("Dark Mode"),
          Switch(
            value: darkMode,
            onChanged: (v) {
              widget.onThemeChanged(v);
              setState(() => darkMode = v);
            },
          ),
          const SizedBox(width: 12),
          const Text("Font"),
          Expanded(
            child: Slider(
              value: fontSize,
              min: 12,
              max: 24,
              divisions: 6,
              label: fontSize.toStringAsFixed(0),
              onChanged: (v) {
                widget.onFontSizeChanged(v);
                setState(() => fontSize = v);
              },
            ),
          ),
        ]),
        ElevatedButton(onPressed: addNote, child: const Text("Add note to SQLite")),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: notes.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(notes[i].title),
              subtitle: Text(notes[i].content),
            ),
          ),
        ),
      ]),
    );
  }
}
