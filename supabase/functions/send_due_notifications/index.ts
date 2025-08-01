import { serve } from "https://deno.land/x/sift@0.5.0/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.18.0";
import { config } from "https://deno.land/x/dotenv@v3.2.0/mod.ts";

// تحميل متغيرات البيئة
config({ export: true });

const supabase = createClient(
 Deno.env.get("SUPABASE_URL") || "",
 Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
);

serve({
 "/send_due_notifications": async (req) => {
  try {
   const today = new Date().toISOString().split("T")[0];
   console.log("📅 تاريخ اليوم:", today);

   const { data: dueInstallments, error: installmentsError } = await supabase
    .from("installments")
    .select("id, customer_id, user_id, due_date, remaining_amount")
    .eq("due_date", today)
    .gt("remaining_amount", 0);

   if (installmentsError) {
    console.error("❌ خطأ بجلب الأقساط:", installmentsError);
    return new Response(JSON.stringify({ error: installmentsError.message }), {
     status: 500,
    });
   }

   if (!dueInstallments || dueInstallments.length === 0) {
    console.log("⚠️ لا توجد أقساط مستحقة اليوم.");
    return new Response(JSON.stringify({ status: "no_due_installments" }));
   }

   const byUser: Record<string, any[]> = {};
   for (const inst of dueInstallments) {
    const uid = inst.user_id;
    if (!byUser[uid]) byUser[uid] = [];
    byUser[uid].push(inst);
   }

   for (const userId of Object.keys(byUser)) {
    const countDue = byUser[userId].length;

    // ✅ نص الإشعار الجديد
    const contentText = `🔔 لديك ${countDue} ${
     countDue === 1 ? "قسط" : "أقساط"
    } مستحقة اليوم.\nاضغط للاطلاع على التفاصيل وتسديد المستحقات.`;

    const message = {
     app_id: Deno.env.get("ONESIGNAL_APP_ID"),
     include_external_user_ids: [userId],
     headings: { en: "📢 إشعار مستحقات", ar: "📢 إشعار مستحقات" },
     contents: { en: contentText, ar: contentText },
     android_sound: "soundnoti",
     chrome_web_icon: "https://i.imgur.com/1b0LVzm.png",
     small_icon: "ic_stat_onesignal_default", // أيقونة صغيرة
     priority: 10,
     android_visibility: 1,
     data: {
      action: "due_installments",
     },
    };

    console.log(`📤 إرسال إلى ${userId}:\n`, message);

    const res = await fetch("https://onesignal.com/api/v1/notifications", {
     method: "POST",
     headers: {
      "Content-Type": "application/json; charset=utf-8",
      Authorization: `Basic ${Deno.env.get("ONESIGNAL_API_KEY")}`,
     },
     body: JSON.stringify(message),
    });

    const result = await res.json();
    if (!res.ok) {
     console.error(`❌ فشل الإرسال للمستخدم ${userId}:`, result.errors);
    } else {
     console.log(
      `✅ تم إرسال الإشعار بنجاح للمستخدم ${userId}: ID ${result.id}`
     );
    }
   }

   return new Response(JSON.stringify({ status: "notifications_sent" }), {
    status: 200,
   });
  } catch (e) {
   console.error("❌ خطأ عام بالدالة:", e);
   return new Response(JSON.stringify({ error: e.message }), {
    status: 500,
   });
  }
 },
});
