# Dashboard Updates - TODO List Feature ✅

## 📋 ملخص التغييرات

تم إضافة نظام TODO List متكامل للـ Dashboard مع الميزات التالية:

### ✨ التغييرات الرئيسية:

#### 1️⃣ **تلوين الـ Greeting بالذهبي** 🟡
```
القديم: "Good evening," (رمادي)
الجديد: "Good evening," (ذهبي - AppColors.accent #D4AF37)
```
**الملف المعدل**: `dashboard_screen.dart` (استخدام RichText)

#### 2️⃣ **إضافة TODO List Section** 📝
موضع جديد تحت "Store Online" badge مباشرة حيث:
- ✅ عرض جميع الـ TODOs الحالية
- ➕ زر إضافة TODO جديد
- ✓ Checkbox لإكمال المهمة
- ❌ زر حذف المهمة
- ⏰ عرض الوقت المتبقي حتى الـ Deadline

---

## 📁 الملفات الجديدة المُنشأة

### 1. `lib/features/dashboard/models/todo_model.dart`
```dart
class TodoItem {
  - id: String (unique identifier)
  - title: String (عنوان المهمة)
  - deadline: DateTime (موعد الانتهاء)
  - createdAt: DateTime (تاريخ الإنشاء)
  - createdBy: String (من أنشأها)
  - isCompleted: bool (هل اكتملت؟)
  
  Methods:
  - isOverdue ← هل انتهت الـ deadline؟
  - timeRemaining ← الوقت المتبقي
  - timeRemainingText ← نص جميل ("2h left")
  - isDueToday / isDueTomorrow ← التحقق من الموعد
  - shouldBeRemoved ← هل تحتاج للحذف؟
}
```

### 2. `lib/features/dashboard/providers/todo_provider.dart`
```dart
class TodoProvider extends ChangeNotifier {
  Methods:
  - loadTodos(token) ← تحميل من Backend/Local Storage
  - addTodo(...) ← إضافة TODO جديد
  - completeTodo(id) ← تحديد كمكتملة
  - deleteTodo(id) ← حذف
  - cleanExpiredTodos() ← حذف المنتهية تلقائياً
  
  Features:
  ✅ Backend integration (مع fallback إلى SharedPreferences)
  ✅ Error handling
  ✅ State management with ChangeNotifier
}
```

### 3. `lib/features/dashboard/widgets/todo_widgets.dart`
```dart
Widgets:

1️⃣ TodoItemWidget
   - يعرض TODO واحد مع:
     • Checkbox للإكمال
     • العنوان
     • الوقت المتبقي بـ color urgency
     • زر الحذف

2️⃣ TodoListSection
   - يعرض قائمة كاملة أو empty state
   - Header مع Count badge
   - Inline handlers للـ complete/delete
```

### 4. `lib/features/dashboard/screens/add_todo_dialog.dart`
```dart
AddTodoDialog Widget:
- Dialog بـ Material Design
- Input field للعنوان (2 lines)
- Date & Time Picker
- Cancel / Add buttons
- Loading state أثناء الإرسال
```

---

## 🔄 التعديلات على الملفات الموجودة

### 1. `main.dart`
```dart
// Added import
import 'package:admin_app/features/dashboard/providers/todo_provider.dart';

// Added to MultiProvider
providers: [
  ChangeNotifierProvider(create: (_) => AuthProvider()),
  ChangeNotifierProvider(create: (_) => TodoProvider()),  // ← NEW
  ...
],
```

### 2. `dashboard_screen.dart`
```dart
// Added imports
import 'package:admin_app/features/dashboard/providers/todo_provider.dart';
import 'package:admin_app/features/dashboard/widgets/todo_widgets.dart';
import 'package:admin_app/features/dashboard/screens/add_todo_dialog.dart';

// Added in initState()
_loadTodos(); // ← NEW

// Greeting styling (RichText + Gold color)
// Before: Text(...) with gray color
// After: RichText with AppColors.accent (Gold)

// Added TodoListSection after Store Online badge
TodoListSection(
  todos: todos,
  onAddTodo: () { ... },
  ...
)
```

### 3. `core/config/api_config.dart`
```dart
// Added new endpoint
static const String todosEndpoint = '$apiPrefix/auth/todos';
```

---

## 🌐 Backend API Requirements

### Required Endpoints to implement:

#### GET `/api/admin/auth/todos`
تحميل جميع TODOs للـ admin الحالي
```json
Response: {
  "todos": [
    {
      "id": "1715601600000",
      "title": "Update inventory",
      "deadline": "2026-05-15T14:30:00Z",
      "createdAt": "2026-05-13T11:29:00Z",
      "createdBy": "Admin Name",
      "isCompleted": false
    }
  ]
}
```

#### POST `/api/admin/auth/todos`
إضافة TODO جديد
```json
Request: {
  "id": "unique_id",
  "title": "Task title",
  "deadline": "ISO8601_datetime",
  "createdAt": "ISO8601_datetime",
  "createdBy": "admin_name",
  "isCompleted": false
}
```

#### PUT `/api/admin/auth/todos/{id}`
تحديث TODO (عادة للـ completion)
```json
Request: {
  "isCompleted": true
}
```

#### DELETE `/api/admin/auth/todos/{id}`
حذف TODO

---

## 🎨 UI/UX Features

### Deadline Color Coding
```
Overdue     → Red (#DC2626)
Due Today   → Orange (#F59E0B)
Due Tomorrow → Gold (#F59E0B)
Future      → Blue (#3B82F6)
```

### Time Display
```
"now"        ← Due right now
"5m left"    ← Minutes remaining
"2h left"    ← Hours remaining
"3d left"    ← Days remaining
"May 15"     ← Far future date
"Overdue"    ← Past deadline
```

### Empty State
- Checkmark icon ✓
- "No pending todos" message
- "Add Todo" button
- Encouraging text

### Full State
- Count badge (number of active todos)
- Add button (+ icon)
- List of todos with inline actions
- Clear visual hierarchy

---

## 💾 Local Storage (Fallback)

إذا كان Backend مش متاح أو في مشكلة:
- TODOs تُحفظ محلياً في `SharedPreferences`
- Key: `admin_todos`
- Format: JSON array
- Syncs with backend عند التوفر

---

## ✅ Testing Checklist

- [ ] تشغيل التطبيق بدون أخطاء
- [ ] الـ greeting يظهر بـ gold color
- [ ] TODO section يظهر تحت Store Online
- [ ] إضافة TODO جديد يعمل
- [ ] Checkbox إكمال المهمة يعمل
- [ ] زر الحذف يعمل
- [ ] Deadline يعرض الوقت المتبقي بشكل صحيح
- [ ] الألوان تتغير بناءً على الـ urgency
- [ ] Empty state يظهر عند عدم وجود todos
- [ ] التطبيق يعمل بدون إنترنت (local storage)
- [ ] عند الاتصال بـ backend، تظهر البيانات المحفوظة

---

## 🚀 الخطوات التالية

### Backend:
1. إنشاء جدول `todos` في Database مع الـ fields
2. Implement الـ 4 endpoints أعلاه
3. التحقق من permissions (كل admin يرى todosه فقط)
4. Handle deadline cleanup (task scheduled)

### Frontend:
1. Test integration مع Backend
2. إضافة UI enhancements (drag & drop reordering, etc.)
3. إضافة notifications عند اقتراب الـ deadline
4. Track TODO completion stats

---

## 💡 Code Quality

✅ Strong typing (no dynamic)
✅ Null safety
✅ Proper error handling
✅ DRY principles
✅ Consistent with existing architecture
✅ Follows Material 3 design
✅ Accessible (colors contrast, font sizes)
✅ Performance optimized (efficient rebuilds)

---

## 📞 Support

إذا واجهت أي مشاكل:
1. تحقق من Backend endpoints
2. افحص console logs للأخطاء
3. تأكد من Token صحيح
4. اختبر مع local storage fallback أولاً
