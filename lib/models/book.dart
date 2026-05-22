class Book {
  final String title;
  final String author;
  final int year;
  final int? coverId;
  final int? editionCount;
  final String? workId;

  Book({
    required this.title,
    required this.author,
    required this.year,
    this.coverId,
    this.editionCount,
    this.workId,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      title: json['title'] ?? '',
      // Handles both OpenLibrary format (author_name list) and stored format (author string)
      author: json['author'] != null
          ? json['author']
          : (json['author_name'] != null
              ? json['author_name'][0]
              : 'Unknown'),
      year: json['year'] ?? json['first_publish_year'] ?? 0,
      coverId: json['coverId'] ?? json['cover_i'],
      editionCount: json['editionCount'] ?? json['edition_count'],
      workId: json['workId'] ?? (json['key'] as String?)?.replaceFirst('/works/', ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'author': author,
      'year': year,
      'coverId': coverId,
      'editionCount': editionCount,
      'workId': workId,
    };
  }
}