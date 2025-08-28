class Note {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String fileUrl;
  final String userName;
  final String userImageUrl;
  final int likes;
  final int dislikes;
  final int views;
  final double rating;

  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.userName,
    required this.userImageUrl,
    required this.likes,
    required this.dislikes,
    required this.views,
    required this.rating,
  });

  factory Note.fromMap(Map<String, dynamic> data, String id) {
    return Note(
      id: id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      userName: data['userName'] ?? '',
      userImageUrl: data['userImageUrl'] ?? '',
      likes: data['likes'] ?? 0,
      dislikes: data['dislikes'] ?? 0,
      views: data['views'] ?? 0,
      rating: (data['rating'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'fileUrl': fileUrl,
      'userName': userName,
      'userImageUrl': userImageUrl,
      'likes': likes,
      'dislikes': dislikes,
      'views': views,
      'rating': rating,
    };
  }
}