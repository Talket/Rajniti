import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrinterService {
  final _supabase = Supabase.instance.client;

  pw.Widget _buildSolidLine({double thickness = 1.0}) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
      height: thickness,
      color: PdfColors.black,
    );
  }

  Future<void> printBillForTable(int tableId, {dynamic orderId}) async {
    try {
      String tableTitle = 'Pick Up';
      if (tableId != 0) {
        final tableRes = await _supabase.from('tables').select('table_number').eq('id', tableId).single();
        tableTitle = 'Table: ${tableRes['table_number']}';
      }

      Map<String, dynamic>? orderRes;

      if (orderId != null) {
        orderRes = await _supabase.from('orders').select().eq('id', orderId).maybeSingle();
      } else {
        orderRes = await _supabase
            .from('orders')
            .select()
            .eq('table_id', tableId)
            .inFilter('status', const ['active', 'printed'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      }

      if (orderRes == null) throw Exception('No printable order found for this table.');
      
      final resolvedOrderId = orderRes['id'];
      final finalTotal = (orderRes['total_amount'] as num?)?.toDouble() ?? 0.0;
      final customerName = orderRes['customer_name']?.toString(); 
      final discount = (orderRes['discount'] as num?)?.toDouble() ?? 0.0;
      final comments = orderRes['comments']?.toString(); 
      final orderSeq = orderRes['yearly_seq'] ?? orderRes['id']; // Fetch Bill No
      
      final grossTotal = finalTotal + discount;

      final itemsRes = await _supabase
          .from('order_items')
          .select('quantity, historical_price, menu_items(name)')
          .eq('order_id', resolvedOrderId);

      final now = DateTime.now();
      final dateString = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year.toString().substring(2)}";
      final timeString = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      int totalQty = 0;

      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          // roll80 creates a continuous roll 80mm wide. 
          pageFormat: PdfPageFormat.roll80, 
          // Tight margins to prevent extra blank spaces
          margin: const pw.EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // HEADER SECTION
                pw.Center(
                  child: pw.Text('Rajniti Dosa', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    '16-17, Swastik Business Hub\nPasodara Missian Road Chowk, Surat', 
                    textAlign: pw.TextAlign.center, 
                    style: const pw.TextStyle(fontSize: 10)
                  )
                ),
                pw.SizedBox(height: 4),
                _buildSolidLine(thickness: 2.0),

                // CUSTOMER SECTION
                if (customerName != null && customerName.isNotEmpty && customerName != 'null') ...[
                  pw.Text('Name: $customerName', style: const pw.TextStyle(fontSize: 12)),
                  _buildSolidLine(thickness: 1.0),
                ],

                // META INFO SECTION (Date, Time, Bill No, Type)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Date: $dateString', style: const pw.TextStyle(fontSize: 12)),
                          pw.Text(timeString, style: const pw.TextStyle(fontSize: 12)),
                          pw.Text('Cashier: Admin', style: const pw.TextStyle(fontSize: 12)),
                        ]
                      )
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(tableTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 12),
                          pw.Text('Bill No.: $orderSeq', style: const pw.TextStyle(fontSize: 12)),
                        ]
                      )
                    ),
                  ]
                ),
                _buildSolidLine(thickness: 1.0),

                // TABLE HEADER
                pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('Item', style: const pw.TextStyle(fontSize: 12))),
                    pw.Expanded(flex: 1, child: pw.Text('Qty.', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 12))),
                    pw.Expanded(flex: 2, child: pw.Text('Price', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
                    pw.Expanded(flex: 2, child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
                  ],
                ),
                _buildSolidLine(thickness: 1.0),

                ...itemsRes.map((item) {
                  final name = item['menu_items'] != null ? item['menu_items']['name'] : 'Item';
                  final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                  final price = (item['historical_price'] as num?)?.toDouble() ?? 0.0;
                  final total = qty * price;
                  
                  totalQty += qty;
                  
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(flex: 4, child: pw.Text(name.toString(), style: const pw.TextStyle(fontSize: 11))),
                        pw.Expanded(flex: 1, child: pw.Text(qty.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 11))),
                        pw.Expanded(flex: 2, child: pw.Text(price.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11))),
                        pw.Expanded(flex: 2, child: pw.Text(total.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11))),
                      ],
                    ),
                  );
                }).toList(),
                
                _buildSolidLine(thickness: 1.0),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 1, child: pw.Text('Total Qty: $totalQty', style: const pw.TextStyle(fontSize: 12))),
                    pw.Expanded(
                      flex: 1, 
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Sub Total', style: const pw.TextStyle(fontSize: 12)),
                          pw.Text(grossTotal.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
                        ]
                      )
                    )
                  ]
                ),

                if (discount > 0) ...[
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('Discount', style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(width: 16),
                      pw.Text('- ${discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12)),
                    ]
                  ),
                ],

                _buildSolidLine(thickness: 2.0),
                
                // GRAND TOTAL
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Grand Total', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs ${finalTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                _buildSolidLine(thickness: 2.0),
                
                if (comments != null && comments.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Center(child: pw.Text('Remarks: $comments', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic))),
                  pw.SizedBox(height: 8),
                ],
                
                pw.Center(
                  child: pw.Text('Thank You & Visit Again', style: const pw.TextStyle(fontSize: 12))
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Bill_${tableTitle.replaceAll(" ", "_")}',
        // THIS IS THE CRITICAL FIX: Forces the printer dialog to respect the continuous roll format!
        format: PdfPageFormat.roll80, 
      );

    } catch (e) {
      debugPrint('Printing failed: $e');
    }
  }

  Future<void> reprintHistoricalBill(dynamic orderId) async {
    try {
      final orderRes = await _supabase
          .from('orders')
          .select('*, tables(table_number)')
          .eq('id', orderId)
          .single();

      final totalAmount = (orderRes['total_amount'] as num?)?.toDouble() ?? 0.0;
      final discount = (orderRes['discount'] as num?)?.toDouble() ?? 0.0;
      final customerName = orderRes['customer_name']?.toString() ?? 'Guest';
      final comments = orderRes['comments']?.toString(); 
      String tableTitle = 'Pick Up';
      if (orderRes['tables'] != null) {
        tableTitle = 'Table: ${orderRes['tables']['table_number']}';
      }
      final orderSeq = orderRes['yearly_seq'] ?? orderRes['id'];
      
      final date = DateTime.parse(orderRes['created_at']).toLocal();
      final dateString = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}";
      final timeString = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

      final itemsRes = await _supabase
          .from('order_items')
          .select('quantity, historical_price, menu_items(name)')
          .eq('order_id', orderId);

      int totalQty = 0;
      final grossTotal = totalAmount + discount;

      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('DUPLICATE BILL', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text('RESTRO POS', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    '123, Restaurant Address, Near Landmark,\nCity, State, 123456', 
                    textAlign: pw.TextAlign.center, 
                    style: const pw.TextStyle(fontSize: 10)
                  )
                ),
                pw.SizedBox(height: 4),
                _buildSolidLine(thickness: 2.0),

                if (customerName != 'Guest' && customerName != '-' && customerName != 'null') ...[
                  pw.Text('Name: $customerName', style: const pw.TextStyle(fontSize: 12)),
                  _buildSolidLine(thickness: 1.0),
                ],

                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Date: $dateString', style: const pw.TextStyle(fontSize: 12)),
                          pw.Text(timeString, style: const pw.TextStyle(fontSize: 12)),
                          pw.Text('Cashier: Admin', style: const pw.TextStyle(fontSize: 12)),
                        ]
                      )
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(tableTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 12),
                          pw.Text('Bill No.: $orderSeq', style: const pw.TextStyle(fontSize: 12)),
                        ]
                      )
                    ),
                  ]
                ),
                _buildSolidLine(thickness: 1.0),

                pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('Item', style: const pw.TextStyle(fontSize: 12))),
                    pw.Expanded(flex: 1, child: pw.Text('Qty.', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 12))),
                    pw.Expanded(flex: 2, child: pw.Text('Price', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
                    pw.Expanded(flex: 2, child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 12))),
                  ],
                ),
                _buildSolidLine(thickness: 1.0),
                
                ...itemsRes.map((item) {
                  final itemName = item['menu_items'] != null ? item['menu_items']['name'] : 'Item';
                  final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                  final price = (item['historical_price'] as num?)?.toDouble() ?? 0.0;
                  final total = qty * price;
                  
                  totalQty += qty;

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(flex: 4, child: pw.Text(itemName.toString(), style: const pw.TextStyle(fontSize: 11))),
                        pw.Expanded(flex: 1, child: pw.Text(qty.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 11))),
                        pw.Expanded(flex: 2, child: pw.Text(price.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11))),
                        pw.Expanded(flex: 2, child: pw.Text(total.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11))),
                      ],
                    ),
                  );
                }).toList(),
                
                _buildSolidLine(thickness: 1.0),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 1, child: pw.Text('Total Qty: $totalQty', style: const pw.TextStyle(fontSize: 12))),
                    pw.Expanded(
                      flex: 1, 
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Sub Total', style: const pw.TextStyle(fontSize: 12)),
                          pw.Text(grossTotal.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
                        ]
                      )
                    )
                  ]
                ),

                if (discount > 0) ...[
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('Discount', style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(width: 16),
                      pw.Text('- ${discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12)),
                    ]
                  ),
                ],

                _buildSolidLine(thickness: 2.0),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Grand Total', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs ${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                _buildSolidLine(thickness: 2.0),
                
                if (comments != null && comments.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Center(child: pw.Text('Remarks: $comments', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic))),
                  pw.SizedBox(height: 8),
                ],
                
                pw.Center(
                  child: pw.Text('Thank You & Visit Again', style: const pw.TextStyle(fontSize: 12))
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Duplicate_Bill_$orderId',
        // CRITICAL FIX FOR DUPLICATES TOO
        format: PdfPageFormat.roll80, 
      );
    } catch (e) {
      debugPrint('Error reprinting historical bill: $e');
      throw Exception('Failed to reprint bill: $e');
    }
  }
}