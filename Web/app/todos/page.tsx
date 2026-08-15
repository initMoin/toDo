import { AppFrame } from "@/components/AppFrame";
import { ToDoWorkspace, type Filter, type Sort } from "@/features/todos/ToDoWorkspace";

export default async function ToDosPage({
  searchParams,
}: {
  searchParams?: Promise<{ filter?: string; sort?: string }> | { filter?: string; sort?: string };
}) {
  const params = await searchParams;
  const filter = isFilter(params?.filter) ? params.filter : "all";
  const sort = isSort(params?.sort) ? params.sort : "position";

  return (
    <AppFrame mode="todos">
      <ToDoWorkspace initialFilter={filter} initialSort={sort} />
    </AppFrame>
  );
}

function isFilter(value: string | undefined): value is Filter {
  return value === "all" || value === "due" || value === "time-sensitive" || value === "collab";
}

function isSort(value: string | undefined): value is Sort {
  return value === "position" || value === "due" || value === "newest";
}
