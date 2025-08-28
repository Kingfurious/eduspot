import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyTeamScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text('My Team')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('teams')
            .where('members', arrayContains: user?.uid)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading teams'));
          }
          if (snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No teams found'));
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  title: Text(data['teamName'] ?? 'Unnamed Team'),
                  subtitle: Text('Members: ${(data['members'] as List).length}'),
                  trailing: IconButton(
                    icon: Icon(Icons.exit_to_app),
                    onPressed: () async {
                      await FirebaseFirestore.instance.collection('teams').doc(doc.id).update({
                        'members': FieldValue.arrayRemove([user?.uid])
                      });
                    },
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}