// lib/screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _selectedAge = 16; // Default age
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- METHODS ---

  Future<void> _register() async {
    // Check if the form is valid before proceeding
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userData = {
        'name': _nameController.text.trim(),
        'age': _selectedAge,
        'registrationCompleted': false,
      };

      final success = await authProvider.registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
        userData,
      );

      if (success && mounted) {
        final user = authProvider.user;
        if (user != null && !user.emailVerified) {
          context.go('/verify-email');
        } else {
          // This case might be for users who are already verified (e.g., social sign-in)
          context.go('/questionnaire');
        }
      } else if (mounted) {
        // Show an error message from the provider if registration fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ??
                'Registration failed. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      // Ensure the loading state is always reset
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.grey[100], // Light, clean background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo (smaller for this screen)
                  SizedBox(
                    height: 60,
                    child: Image.asset('assets/images/clario_logo_bg.jpeg'),
                  ),
                  const SizedBox(height: 24),

                  // Header Text
                  Text(
                    'Create an Account',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join us to start your wellness journey',
                    textAlign: TextAlign.center,
                    style:
                        textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),

                  // --- FORM FIELDS ---
                  _buildFormFields(),

                  const SizedBox(height: 24),

                  // Create Account Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF0C1324), // Primary color
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3, color: Colors.white),
                            )
                          : const Text('Create Account',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign In Link
                  _buildSignInAction(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildFormFields() {
    return Column(
      children: [
        // Full Name
        TextFormField(
          controller: _nameController,
          decoration: _buildInputDecoration(
              labelText: 'Full Name', prefixIcon: Icons.person_outline),
          validator: (value) => (value == null || value.isEmpty)
              ? 'Please enter your name'
              : null,
        ),
        const SizedBox(height: 16),
        // Email
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: _buildInputDecoration(
              labelText: 'Email', prefixIcon: Icons.email_outlined),
          validator: (value) {
            if (value == null ||
                !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // Age Dropdown
        DropdownButtonFormField<int>(
          value: _selectedAge,
          decoration: _buildInputDecoration(
              labelText: 'Age', prefixIcon: Icons.cake_outlined),
          items: List.generate(50, (index) => index + 13) // Ages from 13 to 62
              .map((age) =>
                  DropdownMenuItem(value: age, child: Text('$age years old')))
              .toList(),
          onChanged: (value) => setState(() => _selectedAge = value!),
        ),
        const SizedBox(height: 16),
        // Password
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: _buildInputDecoration(
            labelText: 'Password',
            prefixIcon: Icons.lock_outline,
            suffixIcon: _buildTogglePasswordVisibility(
              isObscured: _obscurePassword,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // Confirm Password
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: _buildInputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: Icons.lock_outline,
            suffixIcon: _buildTogglePasswordVisibility(
              isObscured: _obscureConfirmPassword,
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          validator: (value) {
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  IconButton _buildTogglePasswordVisibility(
      {required bool isObscured, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(
        isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: Colors.grey[600],
      ),
      onPressed: onPressed,
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(prefixIcon, color: Colors.grey[600]),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
    );
  }

  Widget _buildSignInAction(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Already have an account?"),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Sign In',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
