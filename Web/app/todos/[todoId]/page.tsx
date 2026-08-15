import { AppFrame } from "@/components/AppFrame";
import { ToDoDetail } from "@/features/todos/ToDoDetail";

export default async function ToDoDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ todoId: string }> | { todoId: string };
  searchParams?: Promise<{ onboarding?: string }> | { onboarding?: string };
}) {
  const { todoId } = await params;
  const query = await searchParams;

  return (
    <AppFrame mode="detail">
      <ToDoDetail todoId={todoId} onboardingStep={query?.onboarding === "detail" ? "detail" : undefined} />
    </AppFrame>
  );
}
