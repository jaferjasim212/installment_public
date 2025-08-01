import { serve } from "https://deno.land/x/sift@0.5.0/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";
serve(async (req) => {
 const supabase = createClient(
  Deno.env.get("SUPABASE_URL"),
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
 );
 if (req.method !== "POST") {
  return new Response("Method not allowed", {
   status: 405,
  });
 }
 const body = await req.json();
 const { user_id, amount, transaction_id, payment_status } = body;
 if (!user_id || !amount || !payment_status) {
  return new Response("Missing data", {
   status: 400,
  });
 }
 if (payment_status === "success") {
  const { error } = await supabase.from("payments_confirmed").insert({
   user_id,
   amount,
   transaction_id,
   status: payment_status,
   confirmed_at: new Date().toISOString(),
  });
  if (error) {
   return new Response("Database error: " + error.message, {
    status: 500,
   });
  }
  return new Response("Payment confirmed ✅", {
   status: 200,
  });
 }
 return new Response("Payment failed or incomplete", {
  status: 200,
 });
});
