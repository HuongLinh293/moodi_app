import { normalizeCommunityHandle } from "./community.service";

describe("community friend codes", () => {
  it("accepts display formatting and normalizes for lookup", () => {
    expect(normalizeCommunityHandle(" @ABCD 1234-EF56 ")).toBe("abcd1234ef56");
  });

  it("rejects incomplete codes", () => {
    expect(() => normalizeCommunityHandle("abcd")).toThrow(
      "Mã bạn bè phải có đúng 12 chữ hoặc số.",
    );
  });
});
