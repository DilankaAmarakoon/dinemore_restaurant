import 'package:flutter/material.dart';

class FormTextField extends StatefulWidget {
  final String lable;
  final TextEditingController controller;
  final FormTextFieldType type;
  final FocusNode focusNode;

  const FormTextField({
    super.key,
    required this.lable,
    required this.controller,
    required this.type,
    required this.focusNode,
  });

  @override
  State<FormTextField> createState() => _FormTextFieldState();
}
class _FormTextFieldState extends State<FormTextField> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: TextFormField(
        focusNode: widget.focusNode,
        autofocus: false,
        controller: widget.controller,
        keyboardType: setKeybordType(widget.type),
        obscureText: widget.type == FormTextFieldType.password ? true :false,
        decoration: InputDecoration(
            hintText: widget.lable,
            contentPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),

        ),
      ),
    );
  }
  setKeybordType(FormTextFieldType type){
    if(type == FormTextFieldType.text){
      return TextInputType.text;
    }
    else if(type == FormTextFieldType.password){
      return TextInputType.visiblePassword;
    }
  }
}
enum FormTextFieldType {
  text,password,
}