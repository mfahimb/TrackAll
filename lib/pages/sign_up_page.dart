import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:trackall_app/pages/widgets/loading_indicator.dart';

// ── Design tokens (match login_page.dart) ──────
const _navy      = Color(0xFF456FBC);
const _formBg    = Color(0xFFEDF1F9);
const _cardWhite = Color(0xFFFFFFFF);

const _titleNavy = Color(0xFF1E2A4A);
const _subtitle  = Color(0xFF8A93A5);
const _brandBlue = Color(0xFF2D6CDF);

const _inputFill   = Color(0xFFE9EDF7);
const _inputBorder = Color(0xFFDBE2F0);
const _iconGray    = Color(0xFF7A8499);

const _btnLeft  = Color(0xFF1E50E5);
const _btnRight = Color(0xFF3B82F6);

const _footerGry = Color(0xFF9CA3AF);

// TODO: replace with the real registration endpoint once you have it.
const _signUpUrl =
    "https://trackall.rflgroupbd.com/ords/rpro/xxtrac_al/REPLACE_ME_signup";

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController            = TextEditingController();
  final emailController           = TextEditingController();
  final passwordController        = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final _nameFocus     = FocusNode();
  final _emailFocus    = FocusNode();
  final _passFocus     = FocusNode();
  final _confirmFocus  = FocusNode();

  bool obscurePassword        = true;
  bool obscureConfirmPassword = true;
  bool loading                = false;
  bool _btnPressed            = false;

  @override
  void initState() {
    super.initState();
    for (final f in [_nameFocus, _emailFocus, _passFocus, _confirmFocus]) {
      f.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return "Name is required";
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return "Email is required";
    final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!regex.hasMatch(v.trim())) return "Enter a valid email";
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return "Password is required";
    if (v.length < 6) return "Minimum 6 characters";
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    if (v == null || v.isEmpty) return "Please confirm your password";
    if (v != passwordController.text) return "Passwords do not match";
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse(_signUpUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name":     nameController.text.trim(),
          "email":    emailController.text.trim(),
          "password": passwordController.text,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final status  = decoded["status"]?.toString().toUpperCase();
        if (status == "SUCCESS" || decoded["success"] == true) {
          if (mounted) {
            _showMessage("Account created. You can sign in now.");
            Navigator.pop(context);
          }
        } else {
          _showMessage(decoded["message"]?.toString() ?? "Sign up failed");
        }
      } else {
        _showMessage("Server error: ${response.statusCode}");
      }
    } catch (e) {
      _showMessage("Network error: $e");
    }

    if (mounted) setState(() => loading = false);
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: _navy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _formBg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        title: const Text(
          "Create Account",
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 26),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                  decoration: BoxDecoration(
                    color: _cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E2A4A).withValues(alpha: 0.10),
                        blurRadius: 36,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Sign Up",
                        style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: _titleNavy,
                            letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Create your account to get started",
                        style: TextStyle(fontSize: 13, color: _subtitle),
                      ),
                      const SizedBox(height: 22),

                      _buildField(
                        controller: nameController,
                        focusNode: _nameFocus,
                        icon: Icons.person_outline_rounded,
                        hint: "Full Name",
                        validator: _validateName,
                      ),
                      const SizedBox(height: 15),
                      _buildField(
                        controller: emailController,
                        focusNode: _emailFocus,
                        icon: Icons.email_outlined,
                        hint: "Email",
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 15),
                      _buildField(
                        controller: passwordController,
                        focusNode: _passFocus,
                        icon: Icons.vpn_key_outlined,
                        hint: "Password",
                        isPassword: true,
                        obscure: obscurePassword,
                        onToggleObscure: () =>
                            setState(() => obscurePassword = !obscurePassword),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 15),
                      _buildField(
                        controller: confirmPasswordController,
                        focusNode: _confirmFocus,
                        icon: Icons.vpn_key_outlined,
                        hint: "Confirm Password",
                        isPassword: true,
                        obscure: obscureConfirmPassword,
                        onToggleObscure: () => setState(
                            () => obscureConfirmPassword = !obscureConfirmPassword),
                        validator: _validateConfirmPassword,
                      ),
                      const SizedBox(height: 22),

                      loading
                          ? const SizedBox(
                              height: 48,
                              child: Center(child: LoadingIndicator()))
                          : GestureDetector(
                              onTapDown: (_) =>
                                  setState(() => _btnPressed = true),
                              onTapUp: (_) =>
                                  setState(() => _btnPressed = false),
                              onTapCancel: () =>
                                  setState(() => _btnPressed = false),
                              onTap: _submit,
                              child: AnimatedScale(
                                scale: _btnPressed ? 0.97 : 1.0,
                                duration: const Duration(milliseconds: 130),
                                curve: Curves.easeOut,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(9),
                                    gradient: const LinearGradient(
                                      colors: [_btnLeft, _btnRight],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _brandBlue.withValues(
                                            alpha: _btnPressed ? 0.18 : 0.30),
                                        blurRadius: _btnPressed ? 10 : 16,
                                        offset:
                                            Offset(0, _btnPressed ? 3 : 6),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "Create Account",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: "Already have an account? ",
                          style: TextStyle(fontSize: 13, color: _subtitle),
                        ),
                        TextSpan(
                          text: "Sign In",
                          style: TextStyle(
                            fontSize: 13,
                            color: _brandBlue,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 12, color: _footerGry),
                    const SizedBox(width: 6),
                    const Text(
                      "Secure Sign Up  ·  © 2026 MIS. All rights reserved.",
                      style: TextStyle(fontSize: 11, color: _footerGry),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final focused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: focused ? Colors.white : _inputFill,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: focused ? _brandBlue : _inputBorder,
          width: focused ? 1.4 : 1.0,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: _brandBlue.withValues(alpha: 0.10),
                  blurRadius: 6,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: _iconGray),
          const SizedBox(width: 11),
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              obscureText: isPassword ? obscure : false,
              keyboardType: keyboardType,
              validator: validator,
              style: const TextStyle(
                  color: _titleNavy, fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    const TextStyle(color: Color(0xFF9AA3B5), fontSize: 13),
                border: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                errorStyle: const TextStyle(fontSize: 11, height: 0.7),
              ),
            ),
          ),
          if (isPassword)
            GestureDetector(
              onTap: onToggleObscure,
              child: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _iconGray,
                size: 17,
              ),
            ),
        ],
      ),
    );
  }
}