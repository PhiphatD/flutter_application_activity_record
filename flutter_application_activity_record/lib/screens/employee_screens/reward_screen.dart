import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RewardScreen extends StatelessWidget {
  const RewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reward',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Text('Reward Screen (Points, Reward Items, Redeemed)', style: GoogleFonts.poppins()),
      ),
    );
  }
}