import NextLink from "next/link";
import type { ComponentProps } from "react";

type LinkProps = ComponentProps<typeof NextLink>;

/**
 * Keep navigation client-side without invoking Vinext's RSC prefetch runtime.
 * A mixed/stale deployment can otherwise call a missing prefetch helper before
 * the user ever activates a link, which leaves the page noisy and brittle.
 */
export default function Link(props: LinkProps) {
  return <NextLink {...props} prefetch={false} />;
}
