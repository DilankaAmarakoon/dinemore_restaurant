import 'package:flutter/material.dart';

void ShowDialog (context,message){
   showDialog(
    context: context,
    barrierDismissible: false, // Prevent closing by tapping outside
    builder: (_) => Dialog(
      backgroundColor: Colors.black87,
      child: Container(
        padding: EdgeInsets.all(40),
        constraints: BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 80),
            SizedBox(height: 20),
            Text(
              "Action Required",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                fontSize: 24,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text("OK", style: TextStyle(fontSize: 20)),
            )
          ],
        ),
      ),
    ),
  );
}