import 'package:flutter/material.dart';

class CustomTable<T> extends StatelessWidget {
  final List<String> headers;
  final List<T> data;
  final Widget Function(BuildContext context, T item, int index) rowBuilder;
  final bool isLoading;
  final String emptyMessage;

  const CustomTable({
    super.key,
    required this.headers,
    required this.data,
    required this.rowBuilder,
    this.isLoading = false,
    this.emptyMessage = 'No data available',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: headers.map((header) {
              return Expanded(
                flex: _getFlexForHeader(header),
                child: Text(
                  header.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Table Body
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: data.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final item = data[index];
              return Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ), // Taller rows
                child: rowBuilder(context, item, index),
              );
            },
          ),
        ),
      ],
    );
  }

  int _getFlexForHeader(String header) {
    // Simple heuristic for column widths based on header name
    switch (header.toLowerCase()) {
      case 'no':
        return 1;
      case 'name':
      case 'nama':
        return 3;
      case 'aset':
      case 'asset':
        return 3;
      case 'department':
      case 'ruangan':
      case 'organization':
        return 3;
      case 'status':
        return 2;
      case 'action':
      case '':
        return 1;
      default:
        return 2;
    }
  }
}
