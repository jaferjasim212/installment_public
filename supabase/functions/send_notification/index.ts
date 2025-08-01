import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const ONE_SIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_API_KEY")!;
const ONE_SIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID")!;

serve(async (req) => {
 const { user_id, title, message } = await req.json();

 const headers = {
  "Content-Type": "application/json",
  Authorization: `Basic ${ONE_SIGNAL_REST_API_KEY}`,
 };

 const body = {
  app_id: ONE_SIGNAL_APP_ID,
  include_external_user_ids: [user_id],
  headings: { en: title, ar: title },
  contents: { en: message, ar: message },

  priority: 10,
  importance: 5,
  android_visibility: 1,
  android_channel_id: "d95031d2-4c7d-448d-a014-aa7a29ea6cea",
 };

 const response = await fetch("https://onesignal.com/api/v1/notifications", {
  method: "POST",
  headers,
  body: JSON.stringify(body),
 });

 const data = await response.json();

 return new Response(JSON.stringify(data), {
  headers: { "Content-Type": "application/json" },
  status: 200,
 });
});
