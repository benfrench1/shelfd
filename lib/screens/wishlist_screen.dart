import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book.dart';
import '../services/wishlist_service.dart';
import 'review_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Book> _wishlist = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await WishlistService.getWishlist();
    setState(() {
      _wishlist = list;
    });
  }

  Future<void> _remove(Book book) async {
    await WishlistService.removeBook(book);
    await _load();
  }

  void _showOptions(Book book) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.rate_review_outlined,
                  color: Colors.deepOrange,
                ),
                title: const Text('Review Now'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewScreen(book: book),
                    ),
                  ).then((_) => _load());
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Remove from List'),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Remove from Future Reads'),
                      content: const Text(
                          'Are you sure you want to remove this book?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('No'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Yes',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) _remove(book);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String? _coverUrl(int? id) {
    if (id == null) return null;
    return "https://covers.openlibrary.org/b/id/$id-M.jpg";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F2ED),
      body: SafeArea(
        child: Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    const Icon(Icons.travel_explore, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Shelfd',
                      style: GoogleFonts.fredoka(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xff5C3A1E),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Future Reads',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 19),
                      ),
                    ),
                    const SizedBox(width: 96),
                  ],
                ),
              ),
            ),

            // Body
            Expanded(
              child: _wishlist.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.travel_explore,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Your future reads list is empty.",
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Search for books and tap ",
                        style: TextStyle(color: Colors.black38, fontSize: 13),
                      ),
                      const Icon(Icons.bookmark_add_outlined, size: 16, color: Colors.black38),
                      const Text(
                        " to add them.",
                        style: TextStyle(color: Colors.black38, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _wishlist.length,
              itemBuilder: (context, index) {
                final book = _wishlist[index];
                final coverUrl = _coverUrl(book.coverId);

                return GestureDetector(
                  onLongPress: () => _showOptions(book),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: coverUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                coverUrl,
                                width: 46,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 46,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.book, color: Colors.grey),
                                ),
                              ),
                            )
                          : Container(
                              width: 46,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.book, color: Colors.grey),
                            ),
                      title: Text(
                        book.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "${book.author}${book.year > 0 ? '  ·  ${book.year}' : ''}",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                );
              },
            ),
            ),
          ],
        ),
      ),
    );
  }
}
