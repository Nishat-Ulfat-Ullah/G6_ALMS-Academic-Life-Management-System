import 'package:flutter/material.dart';


class MyNotes extends StatelessWidget{
  const MyNotes({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color.fromARGB(255, 138, 201, 243), title: Text("MY Notes")),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(child: 
            Icon(
              Icons.favorite,size: 48
              )
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('H O M E'),
              onTap: () {
                Navigator.pushNamed(context, '/homepage');
              },
            ),
            ListTile(
              leading: Icon(Icons.book),
              title: Text('MY NOTES'),
              onTap: (){
                Navigator.pushNamed(context, '/mynotespage');
              },
            ),
            ListTile(
              leading: Icon(Icons.timer),
              title: Text('MY CONSULTATIONS'),
              onTap: () {
                Navigator.pushNamed(context, '/myconsultations');
              },
            ),
            ListTile(
              leading: Icon(Icons.timer),
              title: Text('BOOK CONSULTATIONS'),
              onTap: () {
                Navigator.pushNamed(context, '/bookconsultations');
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('S E T T I N G S'),
              onTap: (){
                Navigator.pushNamed(context, '/settingspage');
              },
            )

          ],
        ),
      ),
    );
  }
}