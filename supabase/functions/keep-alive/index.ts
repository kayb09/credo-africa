import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (_req: Request) => {
  const timestamp = new Date().toISOString();
  return new Response(
    JSON.stringify({ status: "alive", project: "credo-africa", timestamp }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    }
  );
});
