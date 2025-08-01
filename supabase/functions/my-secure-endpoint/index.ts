// functions/get_credentials/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async () => {
 const config = {
  url: Deno.env.get("SUPABASE_URL"),
  key: Deno.env.get("SUPABASE_ANON_KEY"),
 };

 return new Response(JSON.stringify(config), {
  headers: { "Content-Type": "application/json" },
  status: 200,
 });
});
