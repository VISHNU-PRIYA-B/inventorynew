import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_screen.dart';
import 'department_screen.dart';
import 'forgot_password_screen.dart';
import '../main.dart';
import '../graphql_client.dart';

const String loginMutation = r'''
  mutation Login($name: String!, $password: String!) {
    login(name: $name, password: $password) {
      success
      message
      token
      user {
        id
        name
        teamName
        isAdmin
      }
    }
  }
''';

// 🎨 GLOBAL COLORS (MATCH YOUR LOGO)
const Color primaryColor = Color(0xFF2A2A2A);
const Color accentColor = Color(0xFFC9A227);
const Color bgColor = Color(0xFF0A0E1A);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin(RunMutation runMutation) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');

    // RESET GRAPHQL CLIENT (NO TOKEN)
    final httpLink = HttpLink(backendUrl);
    graphQLClient.value = GraphQLClient(
      link: HttpLink(backendUrl),
      cache: GraphQLCache(store: HiveStore()),
    );


    runMutation({
      'name': _nameCtrl.text.trim(),
      'password': _passCtrl.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Mutation(
        options: MutationOptions(
          document: gql(loginMutation),
          onCompleted: (data) async {
            setState(() => _loading = false);

            if (data == null) return;
            final result = data['login'];

            print("LOGIN RESULT: $result");
            print("Saving user: ${result['user']?['name']}");

            if (result['success'] == true) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('auth_token', result['token']);
              await prefs.setString('user_name', result['user']['name']);
              print("Saving user: ${result['user']?['name']}");
              print("Saved value check: ${prefs.getString('user_name')}");
              await prefs.setBool('is_admin', result['user']['isAdmin'] ?? false);

              final token = result['token'];
              graphQLClient.value = authGraphQLClient(token).value;

              if (!mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const InventoryApp()),
                (route) => false,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['message'] ?? 'Login failed'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          onError: (error) {
            setState(() => _loading = false);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Error: ${error?.graphqlErrors.first.message ?? "Something went wrong"}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          },
        ),
        builder: (runMutation, result) {
          return SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // 🔥 LOGO
                        Container(
                          width: 95,
                          height: 95,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, accentColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFC9A227).withOpacity(0.5),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        Text(
                          'Welcome Back',
                          style: GoogleFonts.outfit(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC9A227),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Sign in to manage your inventory',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        ),

                        const SizedBox(height: 40),

                        _buildField(
                          controller: _nameCtrl,
                          label: 'Username',
                          icon: Icons.person_outline_rounded,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Enter your name' : null,
                        ),

                        const SizedBox(height: 16),

                        _buildField(
                          controller: _passCtrl,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.white38,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Enter password' : null,
                        ),

                        const SizedBox(height: 12),

// 🔐 FORGOT PASSWORD BUTTON
Align(
  alignment: Alignment.centerRight,
  child: GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForgotPasswordScreen(),
        ),
      );
    },
    child: Text(
      "Forgot Password?",
      style: GoogleFonts.outfit(
        color: accentColor,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
),

const SizedBox(height: 20),

                        // 🚀 GRADIENT BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: InkWell(
                            onTap:
                                _loading ? null : () => _doLogin(runMutation),
                            borderRadius: BorderRadius.circular(14),
                            child: Ink(
                              decoration: BoxDecoration(
gradient: const LinearGradient(
  colors: [
    Color(0xFF8A8A8A), // silver
    Color(0xFFC9A227), // gold
  ],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
),
borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: _loading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Text(
                                        'Login',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: GoogleFonts.outfit(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SignupScreen()),
                              ),
                              child: Text(
                                'Sign Up',
                                style: GoogleFonts.outfit(
                                  color: accentColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Color(0xFF9A9A9A), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF1A2035),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Color(0xFFC9A227), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}
