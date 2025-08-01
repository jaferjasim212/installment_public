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
 "/send_due_customers": async () => {
  try {
   const today = new Date().toISOString().split("T")[0];

   // الأقساط المستحقة اليوم
   const { data: dueInstallments, error: dueError } = await supabase
    .from("installments")
    .select("id, customer_id, due_date, remaining_amount")
    .eq("due_date", today)
    .gt("remaining_amount", 0);

   if (dueError) {
    console.error("❌ خطأ بجلب الأقساط:", dueError);
    return new Response(JSON.stringify({ error: dueError.message }), {
     status: 500,
    });
   }

   if (!dueInstallments || dueInstallments.length === 0) {
    console.log("⚠️ لا توجد أقساط مستحقة اليوم.");
    return new Response(JSON.stringify({ status: "no_due_installments" }));
   }

   for (const inst of dueInstallments) {
    const customerId = inst.customer_id;

    const { data: link, error: linkError } = await supabase
     .from("customer_links")
     .select("customer_profile_id")
     .eq("customer_table_id", customerId)
     .maybeSingle();

    if (linkError || !link?.customer_profile_id) {
     console.warn(
      `⚠️ لا يمكن إرسال إشعار للعميل ${customerId}، لم يتم العثور على customer_profile_id`
     );
     continue;
    }

    const formatter = new Intl.NumberFormat("ar-IQ");
    const remainingFormatted = formatter.format(inst.remaining_amount);
    const message = `
📅 إشعار قسط مستحق

لديك قسط مستحق للتسديد اليوم بمبلغ: ${remainingFormatted} د.ع 💰
نرجو تسديده في أقرب وقت، شكرًا لك. 📱`;

    const notif = {
     app_id: Deno.env.get("ONESIGNAL_APP_ID"),
     include_external_user_ids: [link.customer_profile_id],
     headings: { en: "قسطك مستحق اليوم", ar: "قسطك مستحق اليوم" },
     contents: { en: message, ar: message },
     android_sound: "soundnoti",
     chrome_web_icon: "https://i.imgur.com/1b0LVzm.png",
     small_icon: "ic_stat_onesignal_default",
     priority: 10,
     android_visibility: 1,
     data: {
      action: "customer_due_notification",
     },
    };

    const res = await fetch("https://onesignal.com/api/v1/notifications", {
     method: "POST",
     headers: {
      "Content-Type": "application/json; charset=utf-8",
      Authorization: `Basic ${Deno.env.get("ONESIGNAL_API_KEY")}`,
     },
     body: JSON.stringify(notif),
    });

    const result = await res.json();
    if (!res.ok) {
     console.error(`❌ فشل الإرسال للعميل ${customerId}:`, result.errors);
    } else {
     console.log(`✅ تم إرسال الإشعار بنجاح للعميل ${customerId}`);
    }
   }

   return new Response(JSON.stringify({ status: "notifications_sent" }), {
    status: 200,
   });
  } catch (e) {
   console.error("❌ خطأ عام:", e);
   return new Response(JSON.stringify({ error: e.message }), { status: 500 });
  }
 },
});
