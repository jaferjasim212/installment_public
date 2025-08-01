import { serve } from "https://deno.land/x/sift@0.5.0/mod.ts";

serve({
 "/incoming_payment": async (req) => {
  if (req.method !== "POST") {
   return new Response("Method not allowed", { status: 405 });
  }

  try {
   const body = await req.json();
   const { user_id, amount, payment_status } = body;

   if (!user_id || !amount || !payment_status) {
    return new Response("Missing data", { status: 400 });
   }

   if (payment_status !== "success") {
    return new Response("Payment not successful", { status: 200 });
   }

   const res = await fetch(
    "https://acgnemnuljrtvmrlakuf.functions.supabase.co/confirm_payment",
    {
     method: "POST",
     headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
     },
     body: JSON.stringify({ user_id, amount, payment_status }),
    }
   );

   const responseText = await res.text();

   return new Response(`✅ Forwarded: ${responseText}`, { status: res.status });
  } catch (e) {
   return new Response("❌ Internal Server Error", { status: 500 });
  }
 },
});
