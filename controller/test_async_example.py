import asyncio

import pytest
from playwright.async_api import async_playwright, expect


@pytest.mark.asyncio
async def test_example_website():
    """Test een eenvoudige website navigatie en interactie."""
    async with async_playwright() as p:
        # Launch browser
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()

        # Navigeer naar een website
        await page.goto("https://example.com")

        # Controleer de titel
        title = await page.title()
        assert "Example Domain" in title

        # Controleer of een element aanwezig is
        heading = page.locator("h1")
        await expect(heading).to_be_visible()
        await expect(heading).to_have_text("Example Domain")

        # Clean up
        await browser.close()


@pytest.mark.asyncio
async def test_form_submission():
    """Test formulier interactie."""
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()

        await page.goto("https://example.com")

        # Wacht op een specifiek element
        await page.wait_for_selector("h1")

        # Screenshot maken (optioneel)
        await page.screenshot(path="screenshot.png")

        await browser.close()


@pytest.mark.asyncio
async def test_multiple_pages():
    """Test met meerdere pagina's."""
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()

        # Maak twee pagina's
        page1 = await context.new_page()
        page2 = await context.new_page()

        # Navigeer beide pagina's parallel
        await asyncio.gather(
            page1.goto("https://example.com"), page2.goto("https://example.org")
        )

        # Assertions op beide pagina's
        assert "Example Domain" in await page1.title()
        assert "Example" in await page2.title()

        await browser.close()


# Fixture voor hergebruik
@pytest.fixture
async def browser():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        yield browser
        await browser.close()


@pytest.mark.asyncio
async def test_with_fixture(browser):
    """Test die een fixture gebruikt."""
    page = await browser.new_page()
    await page.goto("https://example.com")
    await expect(page.locator("h1")).to_be_visible()
    await page.close()
