import 'package:flutter/material.dart';
class TapButton extends StatefulWidget {
  final String lable;
  final VoidCallback onPressed;
  final Color btnColor;
  final double width;
  final double height;
  final double fontSize;

  const TapButton(
      {
        super.key,
        required this.lable,
        required this.onPressed,
        required this.btnColor,
        required this.width,
        required this.height,
        required this.fontSize,
      }
      );

  @override
  State<TapButton> createState() => _TapButtonState();
}

class _TapButtonState extends State<TapButton> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: ElevatedButton(
        onPressed: widget.onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: Size(widget.width, widget.height),
          side: BorderSide(
            color: Color(0xD0A37C97),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(widget.lable,style: TextStyle(fontWeight: FontWeight.w700,fontSize:widget.fontSize)),
      ),
    );
  }
}