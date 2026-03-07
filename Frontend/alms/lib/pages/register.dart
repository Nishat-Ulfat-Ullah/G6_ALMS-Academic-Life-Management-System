import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final userIdController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final confirmPassController = TextEditingController();

  bool loading = false;

Future<void> registerUser() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => loading = true);

  final host = Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";
  final url = Uri.parse("http://$host:8000/register");

  final body = {
    "user_id": userIdController.text,
    "name": nameController.text,
    "email": emailController.text,
    "password": passController.text,
  };

  try {
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration successful"), backgroundColor: Colors.green),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      String errorMsg = data['detail']?[0]?['msg'] ?? data['message'] ?? "Registration failed";
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Server error: $e"), backgroundColor: Colors.red),
    );
  }

  setState(() => loading = false);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Container(
              height: 400,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/Demo1.png'),
                  fit: BoxFit.fill,
                ),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    width: 120,
                    height: 150,
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/light-1.png'),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 280,
                    width: 120,
                    height: 220,
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/clock.png'),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    child: Container(
                      margin: EdgeInsets.only(top: 300),
                      child: Center(
                        child: Text(
                          "Register",
                          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.all(30),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _box(userIdController, "User ID"),
                    _box(nameController, "Name"),
                    _box(emailController, "Email",
                        validator: (v) => v!.contains("@") ? null : "Invalid Email"),
                    _box(passController, "Password", isPass: true),
                    _box(confirmPassController, "Confirm Password",
                        isPass: true,
                        validator: (v) =>
                            v != passController.text ? "Passwords do not match" : null),

                    SizedBox(height: 25),

                    GestureDetector(
                      onTap: loading ? null : registerUser,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(colors: [
                            Color.fromRGBO(126, 194, 250, 1),
                            Color.fromRGBO(126, 194, 250, 0.6),
                          ]),
                        ),
                        child: Center(
                          child: loading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text("Register",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),

                    SizedBox(height: 40),

                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: Text(
                        "Already have an account? Login",
                        style: TextStyle(
                          color: Color.fromRGBO(126, 194, 250, 1),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _box(TextEditingController c, String text,
      {bool isPass = false, String? Function(String?)? validator}) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(126, 194, 250, 0.4),
            blurRadius: 20.0,
            offset: Offset(0, 10),
          )
        ],
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextFormField(
        controller: c,
        obscureText: isPass,
        validator: validator ??
            (v) {
              if (v == null || v.isEmpty) return "$text is required";
              return null;
            },
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: text,
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
      ),
    );
  }
}
