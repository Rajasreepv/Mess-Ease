import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:messapp/admin/authservice.dart';
import 'package:messapp/admin/dashboard.dart';

import 'package:messapp/admin/login.dart';
import 'package:messapp/global/global.dart';
import 'firebase_options.dart';

Future<void> checkAndUpdateRemainingDays() async {
  QuerySnapshot querySnapshot =
      await FirebaseFirestore.instance.collection('Customers').get();

  querySnapshot.docs.forEach((customerDoc) async {
    print("inside check and update");
    DateTime registrationDate = customerDoc['registrationDate'].toDate();
    // DateTime expirationDate = registrationDate.add(Duration(days: 30));
    DateTime expirationDate = customerDoc['expirationDate'].toDate();
    // Calculate remaining days
    DateTime currentDate = DateTime.now();
    print(registrationDate);
    print(currentDate);
    if (registrationDate.isAfter(currentDate)) {
      print("ys");
      int remainingDays = 30;
      await customerDoc.reference.update({'remainingDays': remainingDays});
    } else {
      print(expirationDate.difference(currentDate).inDays);
      int remainingDays = expirationDate.difference(currentDate).inDays;
      print(remainingDays);
      bool isPaused = customerDoc['isPaused'] ?? false;

      if (!isPaused) {
        remainingDays = (remainingDays > 0) ? remainingDays : 0;
        // Update remaining days logic, for example, decrementing by 1

        // Update Firestore with the new remaining days
        await customerDoc.reference.update({'remainingDays': remainingDays});
        print(remainingDays);
        if (remainingDays == 0 && !isPaused) {
          String phoneNumber =
              customerDoc['phone'].replaceAll(new RegExp(r'[^0-9+]'), '');
          String name = customerDoc['userName'];
          telephony.sendSms(
            to: phoneNumber,
            message: "$name , Your Mess plan has ended today",
          );
          await customerDoc.reference.update({'isPaused': true});
          // Send FCM notification to the user
        }
      }
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const Duration updateInterval = const Duration(seconds: 1);
  Timer.periodic(updateInterval, (Timer timer) {
    checkAndUpdateRemainingDays();
  });

  runApp(MyAppWithNavigator());
}

class MyAppWithNavigator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Navigator(
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const MyApp(),
          );
        },
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  Future<void> checkPreviousLogin(BuildContext context) async {
    final credentials = await AuthService.getCredentials();
    print(credentials['email']);
    print(credentials['password']);

    String? email = credentials['email'];
    String? password = credentials['password'];
    // await fAuth.signInWithEmailAndPassword(
    //     email: credentials['email'], password: credentials['password']);
    if (email!.isNotEmpty && password!.isNotEmpty) {
      if (email == "admin" && password == "123456") {
        Navigator.push(context, MaterialPageRoute(builder: (c) => Dashboard()));
      }
    }

    // if (credentials['email']!.isNotEmpty &&
    //     credentials['password']!.isNotEmpty) {
    //    // Log in the admin user using the stored credentials
    // await fAuth.signInWithEmailAndPassword(
    //     email: credentials['email'], password: credentials['password']);
    // }
  }

  @override
  Widget build(BuildContext context) {
    checkPreviousLogin(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mess Man',
      theme: ThemeData(
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Login(),
    );
  }
}
