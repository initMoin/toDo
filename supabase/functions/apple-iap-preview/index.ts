// Legacy acquisition preview is intentionally retired.
//
// Legacy access is now reconciled from the authenticated account's server-side
// creation date after the public 3.1 cutoff. Keeping this endpoint explicit and
// inert prevents an old client or operator script from reintroducing the former
// AppTransaction-based eligibility path.
Deno.serve((_request) => {
  return new Response(
    JSON.stringify({
      error: "Legacy acquisition preview is retired; use account cutoff reconciliation.",
    }),
    {
      status: 410,
      headers: { "content-type": "application/json" },
    },
  );
});
