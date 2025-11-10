import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'To do',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Text('To do Screen (Upcoming, Unattended, History)', style: GoogleFonts.poppins()),
      ),
    );
  }
}