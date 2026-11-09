/// قالب الفاتورة الافتراضي (يُنشأ عند أول تشغيل)
const String kDefaultInvoiceTemplate = r'''#align:center
#bold
#size:2
{shop_name}
#size:1
#bold:off
{date}
#sep
#align:right
فاتورة رقم: {invoice_no}
العميل: {customer_name}
#sep
{items}
#sep
#bold
#row:الإجمالي|{total}
#bold:off
#align:center
#qr:{invoice_no}
شكراً لزيارتكم
#feed:1''';

/// طباعة تجريبية من الشاشة الرئيسية
const String kTestPrintTemplate = r'''#align:center
#bold
#size:2
PrintEasy
#size:1
#bold:off
طباعة سريعة
#sep
#align:right
اختبار الطباعة العربية: أهلاً بك 123
#row:الصنف|السعر
#row:قلم × 2|10.00
#sep
#align:center
#qr:PrintEasy
#feed:1''';
