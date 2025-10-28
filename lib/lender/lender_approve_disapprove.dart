// import 'package:flutter/material.dart';

// class LenderApproveDisapproveScreen extends StatelessWidget {
//   static const String routeName = '/lender/approve_disapprove';

//   final String itemName;
//   final String borrowerName;
//   final String borrowDate;
//   final String returnDate;
//   final String imagePath;

//   const LenderApproveDisapproveScreen({
//     super.key,
//     required this.itemName,
//     required this.borrowerName,
//     required this.borrowDate,
//     required this.returnDate,
//     required this.imagePath,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final TextEditingController reasonController = TextEditingController();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Approve / Disapprove Request'),
//         centerTitle: true,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             ClipRRect(
//               borderRadius: BorderRadius.circular(16),
//               child: Image.asset(
//                 imagePath,
//                 width: 250,
//                 height: 200,
//                 fit: BoxFit.cover,
//               ),
//             ),
//             const SizedBox(height: 20),
//             Text(
//               itemName,
//               style: const TextStyle(
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 10),
//             Text('Borrower: $borrowerName',
//                 style: const TextStyle(fontSize: 16)),
//             Text('Borrow Date: $borrowDate', style: const TextStyle(fontSize: 16)),
//             Text('Return Date: $returnDate', style: const TextStyle(fontSize: 16)),
//             const SizedBox(height: 20),
//             TextField(
//               controller: reasonController,
//               maxLines: 3,
//               decoration: const InputDecoration(
//                 labelText: 'Reason (optional)',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 30),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton(
//                   onPressed: () {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text('Request Disapproved')),
//                     );
//                     Navigator.pop(context);
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red,
//                     padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
//                   ),
//                   child: const Text('Disapprove'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text('Request Approved')),
//                     );
//                     Navigator.pop(context);
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
//                   ),
//                   child: const Text('Approve'),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
