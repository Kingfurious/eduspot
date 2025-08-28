import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Utility.dart';
import 'app_colors.dart';

class InsightScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const InsightScreen({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBackgroundGradientEnd,
        title: Text('Insights for ${data['title'] ?? 'Post'}', style: TextStyle(color: kTextPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Post Insights', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary)),
            const SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('posts').doc(data['postId']).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: kPrimaryTeal));
                var postData = snapshot.data!.data() as Map<String, dynamic>?;
                int likes = postData?['likes']?.length ?? 0;
                int shares = postData?['shares'] ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Likes: $likes', style: TextStyle(fontSize: 16, color: kTextPrimary)),
                    const SizedBox(height: 8),
                    Text('Shares: $shares', style: TextStyle(fontSize: 16, color: kTextPrimary)),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(data['postId'])
                          .collection('comments')
                          .snapshots(),
                      builder: (context, commentSnapshot) {
                        int comments = commentSnapshot.hasData ? commentSnapshot.data!.docs.length : 0;
                        return Text('Comments: $comments', style: TextStyle(fontSize: 16, color: kTextPrimary));
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}