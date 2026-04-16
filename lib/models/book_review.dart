class BookReview {
  final String title;
  final String author;
  final int year;
  final double rating;
  final String comment;
  final int? coverId;
  final DateTime dateAdded;
  final bool isFavourite;
  final BookFormat format;

  BookReview({
    required this.title,
    required this.author,
    required this.year,
    required this.rating,
    required this.comment,
    this.coverId,
    DateTime? dateAdded,
    this.isFavourite = false,
    this.format = BookFormat.physical,
  }) : dateAdded = dateAdded ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'author': author,
      'year': year,
      'rating': rating,
      'comment': comment,
      'coverId': coverId,
      'dateAdded': dateAdded.toIso8601String(),
      'isFavourite': isFavourite,
      'format': format.name,
    };
  }

  factory BookReview.fromJson(Map<String, dynamic> json) {
    return BookReview(
      title: json['title'],
      author: json['author'],
      year: json['year'],
      rating: json['rating'],
      comment: json['comment'],
      coverId: json['coverId'],
      dateAdded: DateTime.parse(json['dateAdded']),
      isFavourite: json['isFavourite'] ?? false,
      format: _parseFormat(json['format']),
    );
  }

  static BookFormat _parseFormat(String? value) {
    switch (value) {
      case 'audiobook':
        return BookFormat.audiobook;
      case 'braille':
        return BookFormat.braille;
      default:
        return BookFormat.physical;
    }
  }

  BookReview copyWith({
    bool? isFavourite,
    double? rating,
    String? comment,
    BookFormat? format,
  }) {
    return BookReview(
      title: title,
      author: author,
      year: year,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      coverId: coverId,
      dateAdded: dateAdded,
      isFavourite: isFavourite ?? this.isFavourite,
      format: format ?? this.format,
    );
  }
}

enum BookFormat {
  physical,
  audiobook,
  braille,
}
