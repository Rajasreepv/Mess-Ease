import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cool_alert/cool_alert.dart';
import 'package:flutter/material.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sn_progress_dialog/progress_dialog.dart';

import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';

final count = 0;
final telephony = Telephony.instance;
bool isPausedAll = false;
late SharedPreferences _prefs;

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  void initState() {
    super.initState();
    _loadPrefs();
    countfunc();
  }

  countfunc() async {
    QuerySnapshot usersSnapshot =
        await FirebaseFirestore.instance.collection('Customers').get();

    // Get the count of users
    int userCount = usersSnapshot.size;
    setState(() {
      count = userCount;
    });
  }

  Future<void> calculateRemainingDaysAfterResume(String userId) async {
    DocumentSnapshot customerDoc = await FirebaseFirestore.instance
        .collection('Customers')
        .doc(userId)
        .get();

    DateTime expirationDate = customerDoc['expirationDate'].toDate();
    DateTime resumeDate = customerDoc['resumeDate'].toDate();
    DateTime pauseDate = customerDoc['pauseStartDate'].toDate();
    int pausedDays = resumeDate.difference(resumeDate).inDays;

    // Calculate remaining days
    int remainingDays = expirationDate.difference(resumeDate).inDays +
        1; // Include the day of resuming
    remainingDays = (remainingDays > 0) ? remainingDays : 0;

    // Add paused days to the remaining days
    remainingDays += pausedDays;

    // Update Firestore with the new remaining days
    await customerDoc.reference.update({'remainingDays': remainingDays});
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('Customers').get();

    bool allUsersPaused = snapshot.docs.every((doc) => doc['isPaused']);

    setState(() {
      isPausedAll = allUsersPaused;
    });

    await _savePrefs();

    setState(() {
      print(isPausedAll);
      // Load the value opf isPausedAll from SharedPreferences
      isPausedAll = _prefs.getBool('isPausedAll') ?? false;
    });
  }

  Future<void> _savePrefs() async {
    // Save the value of isPausedAll to SharedPreferences
    await _prefs.setBool('isPausedAll', isPausedAll);
  }

  late final Permission _permission;
  String searchQuery = '';
  int count = 10;
  @override
  Widget build(BuildContext context) {
    final _formKey = GlobalKey<FormState>();

    TextEditingController phonecontroller = TextEditingController();
    TextEditingController userName = TextEditingController();
    TextEditingController MessType = TextEditingController();
    TextEditingController place = TextEditingController();
    String messType = 'oneTime';

    Future<void> _handlePauseRestartAllUsers() async {
      try {
        if (!isPausedAll) {
          QuerySnapshot snapshot =
              await FirebaseFirestore.instance.collection('Customers').get();

          for (QueryDocumentSnapshot document in snapshot.docs) {
            await FirebaseFirestore.instance
                .collection('Customers')
                .doc(document.id)
                .update({'isPaused': true});
          }
          CoolAlert.show(
            context: context,
            type: CoolAlertType.success,
            text: "PausedforAll",
          );
          setState(() {
            // isPausedAll = !isPausedAll;
            isPausedAll = true;
          });

          await _savePrefs();
          print(isPausedAll);
        } else {
          QuerySnapshot snapshot =
              await FirebaseFirestore.instance.collection('Customers').get();

          for (QueryDocumentSnapshot document in snapshot.docs) {
            await FirebaseFirestore.instance
                .collection('Customers')
                .doc(document.id)
                .update({'isPaused': false});
          }
          CoolAlert.show(
            context: context,
            type: CoolAlertType.success,
            text: "RestartedforAll",
          );
          setState(() {
            // isPausedAll = !isPausedAll;
            isPausedAll = false;
          });
          await _savePrefs();
          print(isPausedAll);
        }
      } catch (e) {
        print('Error handling all users: $e');
        // Handle error as needed
      }
    }

    Future<void> registerUser() async {
      Timestamp registrationTimestamp = Timestamp.fromDate(DateTime.now());
      // DateTime registrationDate = DateTime.now();
      DateTime registrationDate = registrationTimestamp.toDate();

      // Format the DateTime using intl package
      DateTime expirationDate = registrationDate.add(Duration(days: 30));
      int remainingDays = expirationDate.difference(registrationDate).inDays;
      try {
        await FirebaseFirestore.instance.collection('Customers').add({
          'userName': userName.text,
          'phone': phonecontroller.text,
          'place': place.text,
          'messType': messType,
          'registrationDate': registrationDate,
          'expirationDate': expirationDate,
          'remainingDays': remainingDays, // Initial remaining days
          'isPaused': false,
          'pauseStartDate': null, // Add this field
          'resumeDate': null,
        });
        CoolAlert.show(
          context: context,
          type: CoolAlertType.success,
          text: "Customer Added",
        );

        String phoneNumber =
            phonecontroller.text.replaceAll(new RegExp(r'[^0-9+]'), '');

        telephony.sendSms(
          to: phoneNumber,
          message: "Your Mess has Started from Today",
        );
        print('User data added to Firestore');
      } catch (e) {
        print('Error adding user data: $e');
      }
    }

    _showAddClientDialog() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Add New Student'),
          content: SizedBox(
            height: 400,
            width: 500,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: userName,
                    decoration: InputDecoration(labelText: 'User Name'),
                    // onSaved: (value) => clientName = value!,
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter client name' : null,
                  ),

                  TextFormField(
                    controller: phonecontroller,
                    decoration: InputDecoration(labelText: 'phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  TextFormField(
                    controller: place,
                    decoration: InputDecoration(labelText: 'Place'),
                    keyboardType: TextInputType.text,
                    // onSaved: (value) => place = value!,
                  ),

                  DropdownButtonFormField<String>(
                    value: messType,
                    onChanged: (value) {
                      setState(() {
                        messType = value!;
                      });
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'oneTime',
                        child: Text('1 time - 2000/-'),
                      ),
                      DropdownMenuItem(
                        value: '2 times',
                        child: Text('2 times - 2900/-'),
                      ),
                      DropdownMenuItem(
                        value: '3 times',
                        child: Text('3 times - 3500/-'),
                      ),
                      DropdownMenuItem(
                        value: 'Protein Mess',
                        child: Text('Protein Mess - 4000/-'),
                      ),
                    ],
                    decoration: InputDecoration(labelText: 'Mess Type'),
                  ),
                  // Add a button or widget for photo selection
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();

                  registerUser(); // Handle form submission (save client data and photo)
                  Navigator.pop(context);
                }
              },
              child: Text('Add'),
            ),
          ],
        ),
      );
    }

    ///

    return Scaffold(
      appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                "images/icon1.png",
                height: 40,
                width: 40,
              ),
              SizedBox(
                width: 10,
              ),
              Text(
                "Ibooz Cafe",
                style: TextStyle(
                    fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 3.4),
                    child: Badge(
                      label: Text(
                        count.toString(),
                      ),
                      child: Image.asset(
                        "images/count.png",
                        height: 30,
                        width: 30,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.call,
                      size: 30,
                      color: Colors.red,
                    ), // Replace 'Icons.settings' with the icon you want
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                                  title: Text("Call the Developer"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        launchUrl(
                                            Uri.parse('tel:+917592833494'));
                                        Navigator.pop(context);
                                      },
                                      child: Text('Confirm'),
                                    ),
                                  ]));

                      // Add your action here
                    },
                  ),
                  SizedBox(
                      width:
                          10), // Add some space between the badge and the pause button
                ],
              ),
            ),
          ]),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });

                  // Call a function to filter users based on the search query
                },
                decoration: InputDecoration(
                    labelText: 'Search for users',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10))),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: TextButton(
                      style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all<Color>(
                              Color.fromRGBO(255, 100, 127, 1))),
                      onPressed: () => _showAddClientDialog(),
                      child: Text(
                        "Add New Customer",
                        style: TextStyle(
                            color: Colors.white, fontStyle: FontStyle.italic),
                      )),
                ),
                ElevatedButton(
                  style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          Color.fromRGBO(255, 100, 127, 1))),
                  onPressed: () {
                    print(isPausedAll);
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(isPausedAll
                            ? "Confirm Restart for all Customers!"
                            : "Confirm Pause for all Customers!"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              _handlePauseRestartAllUsers();
                              Navigator.pop(context);
                            },
                            child: Text('Confirm'),
                          ),
                        ],
                      ),
                    );

                    // Add your logic to pause all users when the button is pressed
                  },
                  child: Text(
                    // "pause/restart",
                    isPausedAll ? "Restart All" : "Pause All",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                // ElevatedButton(
                //   onPressed: () async =>
                //       await launchUrl("https://wa.me/${number}?text=Hello"),
                //   child: Text('Open Whatsapp'),
                // ),
              ],
            ),
            Expanded(
              child: _buildCustomerList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerList() {
    _showEditDialog(BuildContext context, DocumentSnapshot customer) {
      TextEditingController editNameController = TextEditingController();
      TextEditingController editPhoneController = TextEditingController();
      TextEditingController editPlaceController = TextEditingController();
      TextEditingController editDate = TextEditingController();
      String editMessType = customer['messType'];

      // Initialize controllers with current values
      editNameController.text = customer['userName'];
      editPhoneController.text = customer['phone'];
      editPlaceController.text = customer['place'];

      DateTime registrationDate = customer['registrationDate'].toDate();
      int year = registrationDate.year;
      int month = registrationDate.month;
      int day = registrationDate.day;
      editDate.text = "$day/$month/$year";
      DateTime currentDate = customer['registrationDate'].toDate();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Edit Student'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: editNameController,
                decoration: InputDecoration(labelText: 'User Name'),
              ),
              TextFormField(
                controller: editPhoneController,
                decoration: InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: editDate,
                readOnly: true,
                onTap: () async {
                  DateTime? selectedDate = await showDatePicker(
                    context: context,
                    initialDate: currentDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );

                  if (selectedDate != null && selectedDate != currentDate) {
                    setState(() {
                      // Convert the selected date to a Timestamp object
                      Timestamp selectedTimestamp =
                          Timestamp.fromDate(selectedDate);
                      // Update the editDate text field
                      editDate.text = selectedTimestamp.toDate().toString();
                    });
                  }
                },
                decoration: InputDecoration(labelText: 'Starting Date'),
                keyboardType: TextInputType.text,
              ),
              TextFormField(
                controller: editPlaceController,
                decoration: InputDecoration(labelText: 'Place'),
                keyboardType: TextInputType.text,
              ),
              DropdownButtonFormField<String>(
                value: editMessType,
                onChanged: (value) {
                  editMessType = value!;
                },
                items: const [
                  DropdownMenuItem(
                    value: 'oneTime',
                    child: Text('1 time - 2000/-'),
                  ),
                  DropdownMenuItem(
                    value: '2 times',
                    child: Text('2 times - 2900/-'),
                  ),
                  DropdownMenuItem(
                    value: '3 times',
                    child: Text('3 times - 3500/-'),
                  ),
                  DropdownMenuItem(
                    value: 'Protein Mess',
                    child: Text('Protein Mess - 4000/-'),
                  ),
                ],
                decoration: InputDecoration(labelText: 'Mess Type'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                DateTime newStartDate = DateTime.parse(editDate.text);
                print(newStartDate);
                DateTime newExpirationDate =
                    newStartDate.add(Duration(days: 30));
                print(newExpirationDate);
                int remainingDays =
                    newExpirationDate.difference(newStartDate).inDays;
                print(remainingDays);
                // Update Firestore with the edited values
                FirebaseFirestore.instance
                    .collection('Customers')
                    .doc(customer.id)
                    .update({
                  'userName': editNameController.text,
                  'phone': editPhoneController.text,
                  'place': editPlaceController.text,
                  'messType': editMessType,
                  'registrationDate':
                      Timestamp.fromDate(DateTime.parse(editDate.text)),
                  'expirationDate': newExpirationDate,
                  'remainingDays': remainingDays
                });

                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Customers')
          .orderBy('remainingDays')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          var customers = snapshot.data!.docs;
//
          var filteredCustomers = customers.where((user) {
            final userName = user['userName'].toString().toLowerCase();
            return userName.contains(searchQuery.toLowerCase());
          }).toList();
//
          print(filteredCustomers);
          return ListView.builder(
            itemCount: filteredCustomers.length,
            // itemCount: customers.length,
            itemBuilder: (context, index) {
              var customer = filteredCustomers[index];
              // var customer = customers[index];
              DateTime registrationDate = customer['registrationDate'].toDate();
              int year = registrationDate.year;
              int month = registrationDate.month;
              int day = registrationDate.day;
              var remainingDays = customer['remainingDays'] ?? 0;
              var status = customer['isPaused'] ? 'Paused' : 'Active';
              var MessType = customer['messType'];
              Future<void> renewSubscription(String userId) async {
                try {
                  // Implement the logic to confirm renewal, possibly using a dialog
                  Timestamp registrationTimestamp =
                      Timestamp.fromDate(DateTime.now());
                  // DateTime registrationDate = DateTime.now();
                  DateTime nwregistrationDate = registrationTimestamp.toDate();
                  DateTime expirationDate =
                      nwregistrationDate.add(Duration(days: 30));
                  // Update Firestore with the renewed remaining days
                  await FirebaseFirestore.instance
                      .collection('Customers')
                      .doc(userId)
                      .update({
                    'isPaused': false,
                    'remainingDays': 30,
                    'registrationDate': nwregistrationDate,
                    'expirationDate': expirationDate
                  });
                } catch (e) {
                  print('Error during renewal: $e');
                }
              }

              Future<void> deleteUser(String userId) async {
                try {
                  await FirebaseFirestore.instance
                      .collection('Customers')
                      .doc(userId)
                      .delete();
                  CoolAlert.show(
                    context: context,
                    type: CoolAlertType.success,
                    text: "User Deleted",
                  );
                } catch (e) {
                  print('Error deleting user: $e');
                }
              }

              return Card(
                elevation: 5,
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ExpansionTile(
                  title: ListTile(
                    title: Text(
                      customer['userName'],
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromRGBO(255, 100, 127, 1)),
                    ),
                    subtitle: Text('Status: $status'),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Remaining Days: $remainingDays',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "StartDate : $day/$month/$year",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'MessType: $MessType',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          onPressed: () async {
                            bool isPaused = customer['isPaused'];

                            if (isPaused) {
                              // Customer is currently paused, so resume
                              if (customer['remainingDays'] == 0) {
                                print("0");
                                showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                            title: Text(
                                                "Cant Activate!!! \nMess has ended \nplease Renew!!!"),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text('Cancel'),
                                              ),
                                            ]));
                              } else {
                                DateTime resumeDate = DateTime.now();
                                await FirebaseFirestore.instance
                                    .collection('Customers')
                                    .doc(customer.id)
                                    .update({
                                  'isPaused': false,
                                  'resumeDate': Timestamp.fromDate(resumeDate),
                                });

                                // Calculate and update remaining days after resuming
                                await calculateRemainingDaysAfterResume(
                                    customer.id);
                              }
                            } else {
                              DateTime pauseDate = DateTime.now();
                              // Customer is currently active, so pause
                              await FirebaseFirestore.instance
                                  .collection('Customers')
                                  .doc(customer.id)
                                  .update({
                                'isPaused': true,
                                'pauseStartDate': Timestamp.fromDate(pauseDate)
                              });
                            }
                            // FirebaseFirestore.instance
                            //     .collection('Customers')
                            //     .doc(customer.id)
                            //     .update({'isPaused': !customer['isPaused']});
                          },
                          icon: customer["isPaused"]
                              ? Icon(
                                  Icons.play_arrow,
                                  color: Colors.black,
                                )
                              : Icon(
                                  Icons.pause,
                                  color: Colors.black,
                                ),
                        ),
                        IconButton(
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                      title: Text("Delete Customer"),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            deleteUser(customer.id);
                                            Navigator.pop(context);
                                          },
                                          child: Text('Confirm'),
                                        ),
                                      ],
                                    ));
                          },
                          icon: Icon(Icons.delete, color: Colors.red),
                        ),
                        IconButton(
                          onPressed: () => _showEditDialog(context, customer),
                          icon: Icon(Icons.edit, color: Colors.blue),
                        ),
                        IconButton(
                          onPressed: () {
                            dynamic rem = remainingDays;
                            print(remainingDays);
                            if (remainingDays == 0) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text("Confirm Renewal"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        renewSubscription(customer.id);
                                        Navigator.pop(context);
                                        CoolAlert.show(
                                          context: context,
                                          type: CoolAlertType.success,
                                          text: "Renewed",
                                        );
                                      },
                                      child: Text('Confirm'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                        backgroundColor: const Color.fromARGB(
                                            255, 229, 173, 173),
                                        title: Text(
                                          "Can't Renew $remainingDays Days Remaining",
                                          style: TextStyle(
                                              fontStyle: FontStyle.italic),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text('Cancel'),
                                          ),
                                        ],
                                      ));
                            }
                          },
                          icon: Icon(Icons.restart_alt, color: Colors.green),
                        ),
                        IconButton(
                            color: Colors.green,
                            onPressed: () {
                              String phone = customer['phone'];

                              launchUrl(Uri.parse('tel:+91$phone'));
                            },
                            icon: Icon(Icons.call)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        }
      },
    );
  }
}
