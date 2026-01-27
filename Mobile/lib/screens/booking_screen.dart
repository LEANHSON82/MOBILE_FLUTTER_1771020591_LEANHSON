import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final ApiService _apiService = ApiService();
  List<dynamic> _courts = [];
  List<dynamic> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchData();
  }

  void _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final courtsRes = await _apiService.dio.get('booking/courts');
      final bookingsRes = await _apiService.dio.get(
        'booking/calendar',
        queryParameters: {
          'from': _focusedDay.subtract(const Duration(days: 30)).toIso8601String(),
          'to': _focusedDay.add(const Duration(days: 30)).toIso8601String(),
        },
      );

      setState(() {
        _courts = courtsRes.data;
        _bookings = bookingsRes.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải dữ liệu sân')),
        );
      }
    }
  }

  Map<String, dynamic>? _getBookingForSlot(int courtId, DateTime time) {
    for (var b in _bookings) {
      final start = DateTime.parse(b['startTime']);
      final end = DateTime.parse(b['endTime']);
      final bCourtId = b['courtId'];
      if (bCourtId == courtId &&
          time.isAfter(start.subtract(const Duration(minutes: 1))) &&
          time.isBefore(end)) {
        return b;
      }
    }
    return null;
  }

  void _showBookingDialog(dynamic court, DateTime time) {
    final user = context.read<AuthProvider>().user;
    final isVip = user != null && (user.walletBalance >= 5000000 || user.roles.contains('Admin')); // Simplification for VIP check

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BookingBottomSheet(
        court: court,
        startTime: time,
        onConfirm: () {
          Navigator.pop(context);
          _fetchData(); // Refresh
        },
        isVip: isVip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2025, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _fetchData();
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() => _calendarFormat = format);
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _fetchData();
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.green.shade200,
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(),
          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.green, 'Trống'),
                const SizedBox(width: 16),
                _buildLegendItem(Colors.red, 'Đã đặt'),
                const SizedBox(width: 16),
                _buildLegendItem(Colors.grey, 'Quá giờ'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async => _fetchData(),
                    child: ListView.builder(
                      itemCount: _courts.length,
                      itemBuilder: (context, index) {
                        final court = _courts[index];
                        return _buildCourtSchedule(court);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildCourtSchedule(dynamic court) {
    final slots = <Widget>[];
    final now = DateTime.now();
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    
    // Generate slots from 6:00 to 22:00
    for (int i = 6; i < 22; i++) {
      final time = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
        i,
      );
      
      final booking = _getBookingForSlot(court['id'], time);
      final isBooked = booking != null;
      final isPast = time.isBefore(now);
      
      Color bgColor;
      Color borderColor;
      Color textColor;
      bool canBook;
      
      if (isPast) {
        bgColor = Colors.grey.shade200;
        borderColor = Colors.grey.shade400;
        textColor = Colors.grey;
        canBook = false;
      } else if (isBooked) {
        bgColor = Colors.red.shade100;
        borderColor = Colors.red;
        textColor = Colors.red;
        canBook = false;
      } else {
        bgColor = Colors.green.shade100;
        borderColor = Colors.green;
        textColor = Colors.green.shade800;
        canBook = true;
      }

      slots.add(
        InkWell(
          onTap: canBook ? () => _showBookingDialog(court, time) : null,
          child: Container(
            width: 60,
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Center(
              child: Text(
                '${i}h',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_tennis, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    court['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text(
                  '${currencyFormat.format(court['pricePerHour'])}/h',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            if (court['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  court['description'],
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: slots),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingBottomSheet extends StatefulWidget {
  final dynamic court;
  final DateTime startTime;
  final VoidCallback onConfirm;
  final bool isVip;

  const _BookingBottomSheet({
    required this.court,
    required this.startTime,
    required this.onConfirm,
    required this.isVip,
  });

  @override
  State<_BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<_BookingBottomSheet> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _isRecurring = false;
  int _duration = 1; // hours
  
  // Recurring vars
  DateTime? _endDate;
  final List<int> _selectedDays = []; // 1=Mon, 7=Sun

  @override
  void initState() {
    super.initState();
    // Default end date + 1 month
    _endDate = widget.startTime.add(const Duration(days: 30));
  }

  void _book() async {
    setState(() => _isLoading = true);
    try {
      if (_isRecurring) {
        if (_selectedDays.isEmpty) {
          throw Exception('Vui lòng chọn ít nhất 1 ngày lặp');
        }
        
        final daysMap = {
          1: 1, // Mon -> DateTime.monday
          2: 2,
          3: 3,
          4: 4,
          5: 5,
          6: 6,
          7: 7 // Sun
        };
        
        final apiDays = _selectedDays.map((d) => daysMap[d]).toList();

        await _apiService.dio.post(
          'booking/recurring',
          data: {
            'courtId': widget.court['id'],
            'startDate': widget.startTime.toIso8601String(),
            'endDate': _endDate!.toIso8601String(),
            'daysOfWeek': apiDays,
            'startTime': DateFormat('HH:mm:ss').format(widget.startTime),
            'endTime': DateFormat('HH:mm:ss').format(widget.startTime.add(Duration(hours: _duration))),
          },
        );
      } else {
         final endTime = widget.startTime.add(Duration(hours: _duration));
         await _apiService.dio.post(
          'booking',
          data: {
            'courtId': widget.court['id'],
            'startTime': widget.startTime.toIso8601String(),
            'endTime': endTime.toIso8601String(),
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đặt sân thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onConfirm();
      }
    } on DioException catch (e) {
      if (mounted) {
        String errorMessage = 'Lỗi đặt sân';
        if (e.response?.data is String) {
          errorMessage = e.response!.data;
        } else if (e.response?.data is Map && e.response?.data['title'] != null) { // ASP.NET default error
           errorMessage = e.response?.data['title'];
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final pricePerHour = (widget.court['pricePerHour'] as num).toDouble();
    var totalPrice = pricePerHour * _duration;
    
    // Estimate recurring price (rough)
    if (_isRecurring && _endDate != null) {
      final days = _endDate!.difference(widget.startTime).inDays;
      final weeks = (days / 7).ceil();
      totalPrice = totalPrice * weeks * _selectedDays.length; 
    }

    final endTimeFormatted = DateFormat('HH:mm').format(widget.startTime.add(Duration(hours: _duration)));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.sports_tennis, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đặt ${widget.court['name']}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.court['description'] ?? '',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // VIP Recurring Switch
          if (widget.isVip)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                   const Icon(Icons.repeat, color: Colors.purple),
                   const SizedBox(width: 12),
                   const Expanded(
                     child: Text(
                       'Đặt lịch định kỳ (VIP)',
                       style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                     ),
                   ),
                   Switch(
                     value: _isRecurring,
                     onChanged: (val) => setState(() => _isRecurring = val),
                     activeColor: Colors.purple,
                   ),
                ],
              ),
            ),
          
          if (_isRecurring) ...[
             const Text('Chọn các ngày trong tuần:', style: TextStyle(fontWeight: FontWeight.bold)),
             const SizedBox(height: 8),
             Wrap(
               spacing: 8,
               children: [
                 for (int i = 1; i <= 7; i++)
                   FilterChip(
                     label: Text(i == 7 ? 'CN' : 'T$i'), // T2, T3... CN
                     selected: _selectedDays.contains(i == 1 ? 2 : (i == 7 ? 8 : i + 1)), // Logic T2=Monday=1 is tricky in Vietnam T2=Monday
                     // Let's use standard ISO: 1=Mon ... 7=Sun
                     // UI: T2 (Mon), T3 (Tue), ... CN (Sun)
                     onSelected: (selected) {
                       setState(() {
                         if (selected) {
                           _selectedDays.add(i);
                         } else {
                           _selectedDays.remove(i);
                         }
                       });
                     },
                     selectedColor: Colors.purple.shade100,
                   ),
               ],
             ),
             const SizedBox(height: 8),
             Row(
               children: [
                 const Text('Đến ngày: '),
                 TextButton(
                   onPressed: () async {
                     final date = await showDatePicker(
                       context: context,
                       initialDate: _endDate!,
                       firstDate: widget.startTime,
                       lastDate: widget.startTime.add(const Duration(days: 365)),
                     );
                     if (date != null) setState(() => _endDate = date);
                   },
                   child: Text(DateFormat('dd/MM/yyyy').format(_endDate!)),
                 ),
               ],
             ),
             const Divider(),
          ],

          // Time Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Bắt đầu', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      DateFormat('HH:mm').format(widget.startTime),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward, color: Colors.green),
                Column(
                  children: [
                    const Text('Kết thúc', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      endTimeFormatted,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Duration Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Thời lượng: '),
              IconButton(
                onPressed: _duration > 1 ? () => setState(() => _duration--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_duration giờ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(
                onPressed: _duration < 4 ? () => setState(() => _duration++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Price
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ước tính tiền:'),
                Text(
                  currencyFormat.format(totalPrice),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Confirm Button
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  onPressed: _book,
                  icon: const Icon(Icons.check),
                  label: Text(_isRecurring ? 'Xác nhận đặt định kỳ' : 'Xác nhận đặt đơn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecurring ? Colors.purple : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
