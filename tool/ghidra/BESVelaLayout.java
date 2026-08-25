// Ghidra Script
// @category BES/Vela
// @menupath BES/Vela/Create BEST1503 memory layout
// @keybinding
// @toolbar
//
// Import the firmware as a raw binary using an ARM little-endian language,
// then run this script from Ghidra's Script Manager.  It recreates the
// evidence-backed memory layout used by the IDA loader supplied with the
// firmware archive.

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.mem.MemoryAccessException;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.listing.Function;

/**
 * Creates a Ghidra memory layout for Xiaomi Vela BEST1503/BEST2700iMP images.
 *
 * The same image bytes are visible through an execute/XIP alias, a cached
 * Flash alias, and a non-cached Flash alias.  The aliases are not guessed:
 * they are recovered from the image footer and the KEY=value build-info
 * block.  p65 uses a different first header word from p62/p67, so the probe
 * accepts both observed variants but still validates the rest of the image
 * structure.
 */
public class BESVelaLayout extends GhidraScript {

	private static final long HEADER_SIZE = 0x10;
	private static final long ENTRY_STUB_OFFSET = 0x10;
	private static final long MAPPED_ENTRY_OFFSET = 0x14;
	private static final long MAPPED_ENTRY_LITERAL_OFFSET = 0x64;

	private static final long MSP_LITERAL_OFFSET = 0x68;
	private static final long MSPLIM_LITERAL_OFFSET = 0x6c;
	private static final long DATA_LMA_LITERAL_OFFSET = 0x70;
	private static final long DATA_START_LITERAL_OFFSET = 0x74;
	private static final long DATA_END_LITERAL_OFFSET = 0x78;
	private static final long BSS_START_LITERAL_OFFSET = 0x7c;
	private static final long BSS_END_LITERAL_OFFSET = 0x80;

	private static final long FOOTER_SIZE = 8;
	private static final long HEADER_VERSION = 0x00050000L;
	private static final long HEADER_RESERVED = 0;
	private static final long STANDARD_HEADER_MAGIC = 0xffffffffL;
	private static final long P65_HEADER_MAGIC = 0xbe57ec1cL;

	private static final byte[] ENTRY_STUB = {
		(byte) 0x14, (byte) 0x48, (byte) 0x00, (byte) 0x47
	};

	private Memory memory;
	private final Set<String> ownedBlockNames = new HashSet<>();

	@Override
	public void run() throws Exception {
		memory = currentProgram.getMemory();
		Layout image = probe();

		println("BES Vela image detected: " + currentProgram.getName());
		println(String.format("  size=0x%x, XIP=0x%08x, entry=0x%08x",
			image.size, image.xipBase, image.mappedEntry));
		if (image.hasAliases()) {
			println(String.format("  cached=0x%08x, non-cached=0x%08x, OTA offset=0x%x",
				image.cachedBase, image.ncBase, image.otaOffset));
			println(String.format("  boot info=file+0x%x -> 0x%08x",
				image.bootInfoOffset, image.bootInfoPtr));
		} else {
			println("  Flash aliases were not validated; only the XIP layout will be created");
		}

		removePreviouslyGeneratedBlocks();
		mapXip(image);
		if (image.hasAliases()) {
			mapFlashAliases(image);
		}
		if (image.hasRamLayout()) {
			mapRam(image);
		}
		describe(image);

		println("BES Vela memory layout created");
	}

	private Layout probe() throws Exception {
		MemoryBlock raw = memory.getBlock(toAddr(0));
		if (raw == null || raw.getStart().getOffset() != 0) {
			throw new IllegalStateException(
				"Import vela_ap.bin as a raw binary at address 0x00000000 first");
		}

		long size = raw.getSize();
		if (size < BSS_END_LITERAL_OFFSET + 4 || size < FOOTER_SIZE) {
			throw new IllegalStateException("Image is too small to be a Vela AP image");
		}

		long magic = readU32(0);
		long version = readU32(4);
		long reserved = readU32(8);
		long bootInfoPtr = readU32(0x0c);
		if ((magic != STANDARD_HEADER_MAGIC && magic != P65_HEADER_MAGIC) ||
			version != HEADER_VERSION || reserved != HEADER_RESERVED ||
			!sameBytes(readBytes(ENTRY_STUB_OFFSET, ENTRY_STUB.length), ENTRY_STUB)) {
			throw new IllegalStateException(
				String.format("Unsupported BES Vela header (magic=0x%08x)", magic));
		}

		long mappedPtr = readU32(MAPPED_ENTRY_LITERAL_OFFSET);
		if ((mappedPtr & 1) == 0) {
			throw new IllegalStateException("Startup target is not a Thumb pointer");
		}
		long mappedEntry = mappedPtr & ~1L;
		if (mappedEntry < MAPPED_ENTRY_OFFSET) {
			throw new IllegalStateException("Invalid mapped startup target");
		}
		long xipBase = mappedEntry - MAPPED_ENTRY_OFFSET;
		if ((xipBase & 0xffffL) != 0 || xipBase + size > 0x100000000L) {
			throw new IllegalStateException("Invalid XIP base");
		}

		Layout image = new Layout(size, xipBase, mappedEntry, bootInfoPtr, magic);
		probeAliases(image);
		probeRam(image);
		return image;
	}

	private void probeAliases(Layout image) throws Exception {
		if (image.size < FOOTER_SIZE) {
			return;
		}
		long mappedNcBase = readU32(image.size - 4);
		if (image.bootInfoPtr < mappedNcBase) {
			return;
		}
		long bootOffset = image.bootInfoPtr - mappedNcBase;
		if (bootOffset < HEADER_SIZE || bootOffset >= image.size - FOOTER_SIZE) {
			return;
		}

		byte[] bootBlob = readBytes(bootOffset, image.size - bootOffset);
		int nul = firstZero(bootBlob);
		if (nul < 0) {
			return;
		}
		Map<String, String> config = parseBootConfig(bootBlob, nul);
		Long flashBase = parseHex(config.get("FLASH_BASE"));
		Long flashNcBase = parseHex(config.get("FLASH_NC_BASE"));
		Long otaOffset = parseHex(config.get("OTA_CODE_OFFSET"));
		if (flashBase == null || flashNcBase == null || otaOffset == null) {
			return;
		}

		long cachedBase = flashBase + otaOffset;
		long ncBase = flashNcBase + otaOffset;
		if (cachedBase > 0xffffffffL || ncBase > 0xffffffffL ||
			ncBase != mappedNcBase || ncBase + image.size > 0x100000000L) {
			return;
		}

		image.otaOffset = otaOffset;
		image.flashBase = flashBase;
		image.flashNcBase = flashNcBase;
		image.cachedBase = cachedBase;
		image.ncBase = ncBase;
		image.bootInfoOffset = bootOffset;
		image.bootTextEndOffset = bootOffset + nul + 1;
		image.bootConfig = config;
	}

	private void probeRam(Layout image) throws Exception {
		if (!image.hasAliases()) {
			return;
		}

		long msp = readU32(MSP_LITERAL_OFFSET);
		long msplim = readU32(MSPLIM_LITERAL_OFFSET);
		long dataLma = readU32(DATA_LMA_LITERAL_OFFSET);
		long dataStart = readU32(DATA_START_LITERAL_OFFSET);
		long dataEnd = readU32(DATA_END_LITERAL_OFFSET);
		long bssStart = readU32(BSS_START_LITERAL_OFFSET);
		long bssEnd = readU32(BSS_END_LITERAL_OFFSET);
		long dataLmaOffset = dataLma - image.cachedBase;
		long dataSize = dataEnd - dataStart;
		if (!(msplim < msp && dataStart < dataEnd && dataEnd == bssStart &&
			bssStart < bssEnd && dataLma >= image.cachedBase &&
			dataLmaOffset >= 0 && dataLmaOffset + dataSize <= image.size)) {
			return;
		}
		if (image.bootInfoOffset != null &&
			dataLmaOffset + dataSize > image.bootInfoOffset) {
			return;
		}

		image.msp = msp;
		image.msplim = msplim;
		image.dataLma = dataLma;
		image.dataLmaOffset = dataLmaOffset;
		image.dataStart = dataStart;
		image.dataEnd = dataEnd;
		image.bssStart = bssStart;
		image.bssEnd = bssEnd;
	}

	private void mapXip(Layout image) throws Exception {
		long textEnd = image.dataLmaOffset != null
			? image.dataLmaOffset
			: image.bootInfoOffset != null ? image.bootInfoOffset : image.size;
		if (textEnd <= HEADER_SIZE || textEnd > image.size) {
			textEnd = image.size;
		}

		createInitialized("BES_HEADER", image.xipBase, 0, HEADER_SIZE,
			false, false, "BES image header");
		createInitialized("BES_XIP_TEXT", image.xipBase + HEADER_SIZE,
			HEADER_SIZE, textEnd - HEADER_SIZE, true, false,
			"BEST1503/BEST2700iMP Thumb XIP code and read-only data");

		if (image.dataLmaOffset != null) {
			long dataEnd = image.bootInfoOffset != null
				? image.bootInfoOffset : image.size;
			if (dataEnd > image.dataLmaOffset) {
				createInitialized("BES_XIP_DATA_LMA", image.xipBase + image.dataLmaOffset,
					image.dataLmaOffset, dataEnd - image.dataLmaOffset,
					false, false, "Initialized DATA image in cached Flash");
			}
		}
		if (image.bootInfoOffset != null && image.bootInfoOffset < image.size) {
			createInitialized("BES_XIP_BOOTINFO", image.xipBase + image.bootInfoOffset,
				image.bootInfoOffset, image.size - image.bootInfoOffset,
				false, false, "Vela boot/build metadata and image trailer");
		}
	}

	private void mapFlashAliases(Layout image) throws Exception {
		createByteMapped("FLASH_CACHED", image.cachedBase, image.xipBase,
			image.size, false, false,
			"Cached Flash alias: FLASH_BASE + OTA_CODE_OFFSET");
		createByteMapped("FLASH_NC", image.ncBase, image.xipBase,
			image.size, false, false,
			"Non-cached Flash alias: FLASH_NC_BASE + OTA_CODE_OFFSET");
	}

	private void mapRam(Layout image) throws Exception {
		long dataSize = image.dataEnd - image.dataStart;
		createInitialized("DATA", image.dataStart, image.dataLmaOffset, dataSize,
			false, true, "Initialized RAM data copied from cached Flash");
		createUninitialized("BSS", image.bssStart, image.bssEnd - image.bssStart,
			"Zero-initialized RAM data");
		createUninitialized("MSP_STACK", image.msplim, image.msp - image.msplim,
			"Main stack range from startup literals");
	}

	private void describe(Layout image) throws Exception {
		label(image.xipBase, "bes_image_header");
		comment(image.xipBase, image.magic == P65_HEADER_MAGIC
			? "p65 BES image header variant"
			: "Standard BES Vela image header");
		label(image.xipBase + 0x0c, "bes_boot_info_ptr_nc");
		comment(image.xipBase + 0x0c,
			"Non-cached Flash pointer to the trailing boot/build-info block");
		label(image.xipBase + ENTRY_STUB_OFFSET, "_start");
		comment(image.xipBase + ENTRY_STUB_OFFSET,
			"BES mapping stub; loads the mapped Thumb startup pointer");
		label(image.xipBase + MAPPED_ENTRY_LITERAL_OFFSET,
			"mapped_startup_pointer");
		label(image.mappedEntry, "mapped_startup");
		comment(image.mappedEntry,
			"Mapped Thumb startup target; branch targets use the execute/XIP alias");

		if (image.hasAliases()) {
			label(image.cachedBase, "bes_flash_cached_image");
			label(image.ncBase, "bes_flash_nc_image");
			label(image.ncBase + image.bootInfoOffset, "bes_boot_info");
			comment(image.ncBase + image.bootInfoOffset,
				"Boot/build metadata referenced by the image header");
			label(image.ncBase + image.size - FOOTER_SIZE,
				"bes_boot_info_integrity");
			label(image.ncBase + image.size - 4,
				"bes_mapped_nc_image_base");
			comment(image.ncBase + image.size - 4,
				"FLASH_NC_BASE + OTA_CODE_OFFSET");

			label(image.xipBase + MSP_LITERAL_OFFSET, "startup_msp_value");
			label(image.xipBase + MSPLIM_LITERAL_OFFSET, "startup_msplim_value");
			label(image.xipBase + DATA_LMA_LITERAL_OFFSET, "startup_data_lma");
			label(image.xipBase + DATA_START_LITERAL_OFFSET, "startup_data_start");
			label(image.xipBase + DATA_END_LITERAL_OFFSET, "startup_data_end");
			label(image.xipBase + BSS_START_LITERAL_OFFSET, "startup_bss_start");
			label(image.xipBase + BSS_END_LITERAL_OFFSET, "startup_bss_end");
			label(image.dataStart, "__data_start");
			label(image.dataEnd, "__data_end__bss_start");
			label(image.bssEnd, "__bss_end");
			label(image.msplim, "__msp_stack_limit");
			label(image.msp, "__msp_stack_top");
		}

		try {
			disassemble(toAddr(image.xipBase + ENTRY_STUB_OFFSET));
			Function function = createFunction(toAddr(image.xipBase + ENTRY_STUB_OFFSET),
				"_start");
			if (function == null) {
				println("  warning: Ghidra could not create _start automatically");
			}
		} catch (Exception error) {
			println("  warning: startup disassembly failed: " + error.getMessage());
		}
	}

	private MemoryBlock createInitialized(String name, long start, long fileOffset,
		long length, boolean execute, boolean write, String blockComment)
		throws Exception {
		if (length <= 0) {
			return null;
		}
		ensureFreeOrOwned(name, start);
		byte[] bytes = readBytes(fileOffset, length);
		MemoryBlock block = memory.createInitializedBlock(name, toAddr(start),
			new ByteArrayInputStream(bytes), length, monitor, false);
		block.setPermissions(true, write, execute);
		block.setComment(blockComment);
		return block;
	}

	private MemoryBlock createByteMapped(String name, long start, long source,
		long length, boolean execute, boolean write, String blockComment)
		throws Exception {
		if (length <= 0) {
			return null;
		}
		ensureFreeOrOwned(name, start);
		MemoryBlock block = memory.createByteMappedBlock(name, toAddr(start),
			toAddr(source), length, false);
		block.setPermissions(true, write, execute);
		block.setComment(blockComment);
		return block;
	}

	private MemoryBlock createUninitialized(String name, long start, long length,
		String blockComment) throws Exception {
		if (length <= 0) {
			return null;
		}
		ensureFreeOrOwned(name, start);
		MemoryBlock block = memory.createUninitializedBlock(name, toAddr(start),
			length, false);
		block.setPermissions(true, true, false);
		block.setComment(blockComment);
		return block;
	}

	private void ensureFreeOrOwned(String name, long start) throws Exception {
		MemoryBlock existing = memory.getBlock(toAddr(start));
		if (existing == null) {
			return;
		}
		if (!ownedBlockNames.contains(existing.getName())) {
			throw new IllegalStateException(String.format(
				"Address 0x%08x is occupied by block %s; use a fresh raw import",
				start, existing.getName()));
		}
		memory.deleteBlock(existing, monitor);
	}

	private void removePreviouslyGeneratedBlocks() throws Exception {
		for (MemoryBlock block : memory.getBlocks()) {
			if (isOwnedName(block.getName())) {
				ownedBlockNames.add(block.getName());
			}
		}
		for (MemoryBlock block : memory.getBlocks()) {
			if (ownedBlockNames.contains(block.getName())) {
				memory.deleteBlock(block, monitor);
			}
		}
		ownedBlockNames.clear();
	}

	private boolean isOwnedName(String name) {
		return name.startsWith("BES_") || name.startsWith("FLASH_") ||
			name.equals("DATA") || name.equals("BSS") || name.equals("MSP_STACK");
	}

	private long readU32(long offset) throws MemoryAccessException {
		byte[] bytes = readBytes(offset, 4);
		return (bytes[0] & 0xffL) | ((bytes[1] & 0xffL) << 8) |
			((bytes[2] & 0xffL) << 16) | ((bytes[3] & 0xffL) << 24);
	}

	private byte[] readBytes(long offset, long length) throws MemoryAccessException {
		if (length < 0 || length > Integer.MAX_VALUE || offset < 0 ||
			offset + length > memory.getBlock(toAddr(0)).getSize()) {
			throw new MemoryAccessException("Invalid raw image range");
		}
		byte[] bytes = new byte[(int) length];
		memory.getBytes(toAddr(offset), bytes);
		return bytes;
	}

	private Map<String, String> parseBootConfig(byte[] bytes, int nul) {
		String text = new String(bytes, 0, nul, StandardCharsets.US_ASCII);
		Map<String, String> result = new HashMap<>();
		for (String line : text.split("\\r?\\n")) {
			int equals = line.indexOf('=');
			if (equals <= 0) {
				continue;
			}
			String key = line.substring(0, equals).trim();
			String value = line.substring(equals + 1).trim();
			if (!key.isEmpty()) {
				result.put(key, value);
			}
		}
		return result;
	}

	private Long parseHex(String value) {
		if (value == null || value.isEmpty()) {
			return null;
		}
		try {
			return Long.decode(value);
		} catch (NumberFormatException error) {
			return null;
		}
	}

	private int firstZero(byte[] bytes) {
		for (int index = 0; index < bytes.length; index++) {
			if (bytes[index] == 0) {
				return index;
			}
		}
		return -1;
	}

	private boolean sameBytes(byte[] left, byte[] right) {
		if (left.length != right.length) {
			return false;
		}
		for (int index = 0; index < left.length; index++) {
			if (left[index] != right[index]) {
				return false;
			}
		}
		return true;
	}

	private void label(long address, String name) {
		try {
			createLabel(toAddr(address), name, true);
		} catch (Exception error) {
			println(String.format("  warning: label %s at 0x%08x: %s",
				name, address, error.getMessage()));
		}
	}

	private void comment(long address, String text) {
		try {
			setPlateComment(toAddr(address), text);
		} catch (Exception error) {
			println(String.format("  warning: comment at 0x%08x: %s",
				address, error.getMessage()));
		}
	}

	private static final class Layout {
		final long size;
		final long xipBase;
		final long mappedEntry;
		final long bootInfoPtr;
		final long magic;

		Long otaOffset;
		Long flashBase;
		Long flashNcBase;
		Long cachedBase;
		Long ncBase;
		Long bootInfoOffset;
		Long bootTextEndOffset;
		Map<String, String> bootConfig = new HashMap<>();

		Long msp;
		Long msplim;
		Long dataLma;
		Long dataLmaOffset;
		Long dataStart;
		Long dataEnd;
		Long bssStart;
		Long bssEnd;

		Layout(long size, long xipBase, long mappedEntry, long bootInfoPtr,
			long magic) {
			this.size = size;
			this.xipBase = xipBase;
			this.mappedEntry = mappedEntry;
			this.bootInfoPtr = bootInfoPtr;
			this.magic = magic;
		}

		boolean hasAliases() {
			return cachedBase != null && ncBase != null && bootInfoOffset != null;
		}

		boolean hasRamLayout() {
			return dataLmaOffset != null && dataStart != null && dataEnd != null &&
				bssStart != null && bssEnd != null && msp != null && msplim != null;
		}
	}
}
