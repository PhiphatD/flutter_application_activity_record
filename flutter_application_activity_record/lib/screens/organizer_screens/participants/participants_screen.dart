import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ParticipantsScreen extends StatelessWidget {
  const ParticipantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Participants',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4A80FF),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Text(
          'Participants Screen',
          style: GoogleFonts.poppins(color: Colors.grey[700]),
        ),
      ),
    );
  }
}
