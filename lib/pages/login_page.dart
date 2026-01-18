import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackall_app/pages/widgets/loading_indicator.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkSession();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      usernameController.text = prefs.getString('remembered_user') ?? '';
      passwordController.text = prefs.getString('remembered_pass') ?? '';
      rememberMe = prefs.getBool('remember_me') ?? false;
    });
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final loginTime = prefs.getInt('loginTime');

    if (userId != null && loginTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - loginTime < 3600 * 1000) {
        Navigator.pushReplacementNamed(context, '/company_select');
      } else {
        await prefs.remove('userId');
        await prefs.remove('loginTime');
      }
    }
  }

  Future<void> login() async {
    setState(() => loading = true);

    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    try {
      final uri = Uri.parse(
          "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/login_auth");

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Cache-Control": "no-store",
          "Pragma": "no-cache",
          "Expires": "0",
        },
        body: "p_username=$username&p_password=$password",
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userId', username);
          await prefs.setInt(
              'loginTime', DateTime.now().millisecondsSinceEpoch);

          if (rememberMe) {
            await prefs.setString('remembered_user', username);
            await prefs.setString('remembered_pass', password);
            await prefs.setBool('remember_me', true);
          } else {
            await prefs.remove('remembered_user');
            await prefs.remove('remembered_pass');
            await prefs.setBool('remember_me', false);
          }

          Navigator.pushReplacementNamed(context, '/company_select');
        } else if (data['error'] != null) {
          showMessage(data['error']);
        } else {
          showMessage("Invalid username or password");
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFB6E0FE), Color(0xFFEAF6FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(60),
                    bottomRight: Radius.circular(60),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.9)),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 18,
                              offset: Offset(0, 8)),
                        ],
                      ),
                      child: ShaderMask(
                        shaderCallback: (bounds) =>
                            const LinearGradient(
                          colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
                        ).createShader(bounds),
                        child: const Text(
                          "TrackAll",
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Smart tracking. Better control.",
                      style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF5C7C99),
                          letterSpacing: 0.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildTextField(
                        controller: usernameController,
                        icon: Icons.person,
                        hint: "User ID"),
                    const SizedBox(height: 20),
                    _buildTextField(
                        controller: passwordController,
                        icon: Icons.lock,
                        hint: "Password",
                        isPassword: true),
                    Row(
                      children: [
                        Checkbox(
                          value: rememberMe,
                          activeColor: const Color(0xFF5C9DED),
                          onChanged: (value) {
                            setState(() => rememberMe = value!);
                          },
                        ),
                        const Text(
                          "Remember Me",
                          style: TextStyle(
                              color: Color(0xFF5C7C99),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    loading
                        ? const LoadingIndicator()
                        : SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5C9DED),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 3,
                              ),
                              onPressed: login,
                              child: const Text(
                                "Login",
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10)],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF5C9DED)),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}
