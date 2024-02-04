import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:messapp/admin/authservice.dart';
import 'package:messapp/admin/dashboard.dart';
import 'package:messapp/admin/loginpageanimation/custom_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _blurAnimation;
  Animation<double>? _fadeAnimation;
  Animation<double>? _sizeAnimation;
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _blurAnimation = Tween<double>(
      begin: 50,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: Curves.ease,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOutQuint,
      ),
    );

    _sizeAnimation = Tween<double>(
      begin: 0,
      end: 500,
    ).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: Curves.decelerate,
      ),
    );

    _controller?.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // timeDilation = 8;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        child: SingleChildScrollView(
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _blurAnimation!,
                builder: (context, widget) {
                  return Container(
                    height: 400,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage("images/background1.png"),
                        fit: BoxFit.fill,
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(left: 40, right: 40, top: 20),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _sizeAnimation!,
                      builder: (context, widget) {
                        return Container(
                          width: _sizeAnimation?.value,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.grey,
                                blurRadius: 80,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              CustomInput(
                                hint: 'e-mail',
                                obscure: false,
                                icon: Icon(Icons.person),
                                controller: emailController,
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey,
                                      spreadRadius: 0.5,
                                      blurRadius: 0.5,
                                    ),
                                  ],
                                ),
                              ),
                              CustomInput(
                                hint: 'password',
                                obscure: true,
                                icon: Icon(Icons.lock),
                                controller: passwordController,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _fadeAnimation!,
                      child: SizedBox(
                        width: 300,
                        height: 43,
                        child: ElevatedButton(
                          onPressed: () {
                            print(emailController.text);
                            print(passwordController.text);
                            if (emailController.text == "admin" &&
                                passwordController.text == "123456") {
                              AuthService.saveCredentials(emailController.text,
                                  passwordController.text);

                              Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (c) => Dashboard()));
                            }
                            emailController.text = "";
                            passwordController.text = "";
                          },
                          style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all<Color>(
                                  Color.fromRGBO(255, 100, 127, 1))),
                          child: Text(
                            "Login",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    )
                    // AnimatedButton(controller: _controller!),
                    ,
                    const SizedBox(height: 10),
                    FadeTransition(
                      opacity: _fadeAnimation!,
                      child: const Text(
                        "Forgot my password",
                        style: TextStyle(
                          color: Color.fromRGBO(255, 100, 127, 1),
                          fontWeight: FontWeight.bold,
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
}
