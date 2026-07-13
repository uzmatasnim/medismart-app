// lib/screens/auth/login_screen.dart
// UC-02 + UC-03: Login + Password Reset

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medismart/services/auth_service.dart';
import 'package:medismart/screens/auth/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() { _emailController.dispose(); _passwordController.dispose(); super.dispose(); }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.loginUser(email: _emailController.text.trim(), password: _passwordController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
  }

  Future<void> _handleForgotPassword() async {
    final emailController = TextEditingController(text: _emailController.text);
    final result = await showDialog<String>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter your email to receive a password reset link:'),
          const SizedBox(height: 12),
          TextField(controller: emailController,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, emailController.text.trim()), child: const Text('Send')),
        ],
      ));
    if (result == null || result.isEmpty) return;
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.resetPassword(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? '✅ Password reset email sent! Check your inbox.'),
      backgroundColor: error == null ? Colors.green : Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: Form(key: _formKey, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.medication, size: 80, color: Color(0xFF2196F3)),
          const SizedBox(height: 16),
          const Text('MediSmart', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2196F3)), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Your Health Companion', style: TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 48),
          TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, enabled: !_isLoading,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
            validator: (v) => v == null || v.isEmpty ? 'Please enter your email' : !v.contains('@') ? 'Enter a valid email' : null),
          const SizedBox(height: 16),
          TextFormField(controller: _passwordController, obscureText: _obscurePassword, enabled: !_isLoading,
            decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock), border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword))),
            validator: (v) => v == null || v.isEmpty ? 'Please enter your password' : v.length < 6 ? 'Min 6 characters' : null),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight,
            child: TextButton(onPressed: _isLoading ? null : _handleForgotPassword, child: const Text('Forgot Password?'))),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isLoading ? const SizedBox(height:20,width:20,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2))
                : const Text('Login', style: TextStyle(fontSize: 16))),
          const SizedBox(height: 16),
          TextButton(onPressed: _isLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
            child: const Text("Don't have an account? Register")),
        ]))))));
  }
}
