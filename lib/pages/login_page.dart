import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);

   final url = Uri.parse("https://trackall-1.onrender.com/login");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": usernameController.text.trim(),
          "password": passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // HRIS response: check succesS_CODE
        if (data["succesS_CODE"] == "2000") {
          // Login successful
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          showMessage(data["succesS_MESSAGE"] ?? "Invalid credentials");
        }
      } else {
        showMessage("Server error: ${response.statusCode}");
      }
    } catch (e) {
      showMessage("Network error: $e");
    }

    setState(() => loading = false);
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  "TrackAll",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: "User ID"),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: "Password"),
                  obscureText: true,
                ),
                const SizedBox(height: 32),
                loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: login,
                        child: const Text(
                          "Login",
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
