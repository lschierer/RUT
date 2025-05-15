import { z } from "zod";

export const Tag = z.record(z.string(), z.number());
export type Tag = z.infer<typeof Tag>;
