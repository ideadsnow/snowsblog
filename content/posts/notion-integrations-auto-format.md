+++
date = '2024-11-20T22:00:00+08:00'
draft = false
title = 'Notion Integrations 开发：实现一个自动格式化工具'
tags = ['Notion']
categories = ["Handbook"]
series = []
+++
## 背景

最近在尝试转用 Notion，发现没有内建格式化功能，可以做到自动在中文和英文、中文和数字之间添加空格，而这个功能在飞书文档中是有一个菜单小组件可以实现的。于是稍微研究了一下 Notion 的开放能力，自己实现了一个格式化小工具

## 思路

既然没有内置格式化功能，那么就要通过开放 API 自己实现了，正好 Notion 在这方面做的很不错，有一套称为 [集成（Integrations）](https://www.notion.com/integrations/all) 的开放能力体系，目前很多知名产品都通过集成和 Notion 做了连接，俨然已经是一个生态了

> **What is a Notion Integration?**
>
> A Notion integration, sometimes referred as a [connection](https://www.notion.so/help/add-and-manage-connections-with-the-api), enables developers to programmatically interact with Notion workspaces. These integrations facilitate linking Notion workspace data with other applications or the automation of workflows within Notion.
>
> Integrations are installed in Notion workspaces and require **explicit permission** from users to access Notion pages and databases.
>
> Notion users have access to a vast [library](https://www.notion.so/integrations/all) of existing integrations to enrich their experience further. For developers interested in creating custom solutions, Notion supports the development of both internal and public integrations. Both utilize the Notion API for workspace interactions.

{{< image src="https://webp.slightsnow.com/2024/11/554a8f3a285314ff2f3240172e382ee0.png" caption="Notion Integrations" >}}

而我们自己也可以非常方便地通过这个开放能力，实现一切自定义需求

现在我们需要实现一个自动格式化工具，那么大体上需要这些能力：鉴权、获取文档内容、修改文档内容

## 实现

### 创建集成

打开 [我的集成](https://www.notion.so/profile/integrations) 页面，创建一个新集成，并选择「读取内容」、「更新内容」、「插入内容」权限，保存该集成

{{< image src="https://webp.slightsnow.com/2024/11/e6ca795386eaf55227a5560c7ef470b4.png" caption="My Integrations" >}}

**注意：** 这里会自动创建一个内部集成密钥，这个密钥将会是外部系统与 Notion 建立连接鉴权的唯一凭证。可以复制下来备用

### 通过 API 操作文档

Notion 提供了一套 [API](https://developers.notion.com/docs/getting-started) 来支持集成操作 Notion，对应的 SDK 有 Javascript 版本和 Python 版本两种

### 安装依赖

这里我们用 Python 来开发，直接安装依赖：

```bash
pip install notion-client
```

### 代码实现

首先考虑最关键的部分，如何实现在中文和英文、中文和数字之间加空格？通常可以用正则表达式来实现，我们定义一个函数

```python
def format_text(text: str) -> str:
    """Add spaces between Chinese and English/numbers"""
    text = re.sub(r"([\u4e00-\u9fa5])([A-Za-z0-9])", r"\1 \2", text)
    text = re.sub(r"([A-Za-z0-9])([\u4e00-\u9fa5])", r"\1 \2", text)
    return text
```

实现起来非常简单，对吧！

但是作为一个完善的工具，在工程层面要考虑得更多：

1. 如何和 Notion 进行连接？
2. 如何获取文档内容？
3. 如何将替换后的文本更新？
4. 性能角度考虑，能否批量更新？更新失败、冲突如何重试？
5. 代码可维护性？

现在让我们一步步来解决这些问题

#### 与 Notion 建立链接（鉴权）

如前文所述，我们创建了一个新的集成，并且获得了它的「内部集成密钥」，那么在实现代码中，我们在初始化 Notion Client 的时候将其作为参数传入

```python
NOTION_TOKEN = "your_integration_token"
notion = AsyncClient(auth=NOTION_TOKEN)
```

但这仅仅只是允许了这个集成能够与你的 Notion 进行连接，但是如果要操作具体的文档，还需要将文档授权给这个集成，流程如下：

1. 首先在页面右上角点击菜单按钮
2. 在弹出的菜单中，点击底部的「连接」
3. 在搜索框中，你应该能看到你之前创建的集成（Integration）的名称
4. 选择你的集成（Integration）并添加授权

完成这些步骤后，就可以菜单的「连接」中看到你的集成（Integration）已被列出，这时集成（Integration）就有权限访问该页面了

**不过注意**，需要为每个想要通过 API 访问的页面重复这个过程。如果想处理整个数据库或者父页面下的所有内容，只需要给父页面添加权限即可，子页面会自动继承权限

#### 获取块对象

我们需要知道 Notion 是 Block 化的，也就是说整个文档都是由不同的 Block 组成的，我们要更新文档，实际上就是要更新所有的文本 Block 的内容

梳理常见的文本块类型如下：

```python
- paragraph
- heading_1
- heading_2
- heading_3
- bulleted_list_item
- numbered_list_item
- toggle
- quote
- callout
- to_do
- template
- synced_block
- breadcrumb
- table_of_contents
- link_to_page
- table_row
- column_list
- column
```

此外，我们希望同时能够处理文档标题，而标题其实也是一个 Block，类型属性名为 `title`

针对标题 Block，需要使用 pages 模块的 retrieve 函数，关键代码：

```python
page = notion.pages.retrieve(page_id)
if "properties" in page:
    ## Find the title property (could be 'title' or 'Name', etc.)
    for prop_name, prop_value in page["properties"].items():
        if prop_value["type"] in ["title"]:
            title_property = prop_name
            break
```

`page["properties"][title_property]` 就是标题 Block 对象

针对其他文本 Block，需要使用 Blocks 模块的 retrieve 函数，关键代码：

```python
block = notion.blocks.retrieve(block_id)
```

同时，Block 是可以嵌套的，所以还需要对嵌套情况进行处理

```python
children = notion.blocks.children.list(block_id)
// 递归对 children 进行处理，详见文末完整源码链接
```

### 文本处理

如前文所述，在拿到每个 Block 后，可以直接将其文本内容交给 `format_text` 函数做正则处理，生成目标文本，再回顾一下处理函数：

```python
def format_text(text: str) -> str:
    """Add spaces between Chinese and English/numbers"""
    text = re.sub(r"([\u4e00-\u9fa5])([A-Za-z0-9])", r"\1 \2", text)
    text = re.sub(r"([A-Za-z0-9])([\u4e00-\u9fa5])", r"\1 \2", text)
    return text
```

### 修改块对象

也很简单， 无非是调用一下 修改 API，关键代码：

```python
notion.blocks.update(
    block_id=block["block_id"],
    **{block["block_type"]: {"rich_text": block["content"]}},
)
```

### 进一步优化

到目前为止，基本流程已经可以串联起来了，但是为了提升更新速度，我们需要进一步优化，支持批量并发修改。这个业务场景是典型的 IO 密集型应用，所以直接使用 async/await 异步模型对代码进行优化，最终的功能入口代码如下所示：

```python
async def format_notion_page(page_id: str):
    formatter = NotionFormatter()

    start_time = datetime.now()
    print(f"Starting formatting... ({start_time})")

    ## Format page title first
    print("Formatting page title...")
    await formatter.format_page_title(page_id)

    ## Then format page content
    print("\nCollecting blocks to update...")
    await formatter.collect_blocks(page_id)

    print(f"\nScan completed:")
    print(f"- Total blocks scanned: {formatter.total_blocks}")
    print(f"- Blocks to update: {len(formatter.blocks_to_update)}")

    if formatter.blocks_to_update:
        await formatter.update_blocks()

        ## Handle failed blocks
        if formatter.failed_blocks:
            print("\nRetry failed blocks? (y/n)")
            if input().lower() == "y":
                formatter.blocks_to_update = formatter.failed_blocks
                formatter.failed_blocks = []
                await formatter.update_blocks()

    end_time = datetime.now()
    duration = end_time - start_time
    print(f"\nProcess completed! Total time: {duration}")
```

此外，还需要进一步考虑细节，Notion 存在 API 限频策略：

- 每个集成每秒最多可以发送 3 个请求（3 requests/second）
- 每个工作区每秒最多可以发送 30 个请求（30 requests/workspace/second）

同时 Notion 还不支持一个集成并行修改文档，遇到冲突时 API 会返回错误，导致修改失败

因此，我们需要考虑控制请求频率，以及实现错误重试策略，相关代码：

```python
async def update_single_block(self, block: Dict, retry_count: int = 3):
    """Update a single block with retry mechanism"""
    for attempt in range(retry_count):
        try:
            ## Get the latest block state
            current_block = await notion.blocks.retrieve(block["block_id"])

            ## Check if the block has been modified
            if (
                current_block.get("last_edited_time", "")
                != block["last_edited_time"]
            ):
                content = current_block[block["block_type"]]["rich_text"]
                updated_content, modified = self.process_rich_text(content)
                if not modified:
                    return True
                block["content"] = updated_content

            await notion.blocks.update(
                block_id=block["block_id"],
                **{block["block_type"]: {"rich_text": block["content"]}},
            )
            return True

        except Exception as e:
            if attempt < retry_count - 1:
                wait_time = (attempt + 1) * 0.5
                print(
                    f"Failed to update block {block['block_id']}, retry in {wait_time}s: {str(e)}"
                )
                await asyncio.sleep(wait_time)
            else:
                print(
                    f"Failed to update block {block['block_id']} after all attempts: {str(e)}"
                )
                return False

async def update_blocks(self, batch_size: int = 3):
    """Update collected blocks in batches"""
    total = len(self.blocks_to_update)
    print(f"\nStarting to update {total} blocks...")

    for i in range(0, total, batch_size):
        batch = self.blocks_to_update[i : i + batch_size]

        results = await asyncio.gather(
            *[self.update_single_block(block) for block in batch],
            return_exceptions=False,
        )

        failed_blocks = [
            block for block, success in zip(batch, results) if not success
        ]
        self.failed_blocks.extend(failed_blocks)

        print(f"Processed {min(i + batch_size, total)}/{total} blocks")
        await asyncio.sleep(0.5)

    success_count = total - len(self.failed_blocks)
    print(f"\nUpdate completed:")
    print(f"- Success: {success_count}/{total}")
    if self.failed_blocks:
        print(f"- Failed: {len(self.failed_blocks)}/{total}")
```

这段代码实现了并发数量限制最大为 3，且遇到冲突更新失败时会自动重试，重试时间遵循指数退避原则

## 使用效果

初始文档

{{< image src="https://webp.slightsnow.com/2024/11/360a31bbbf3fbbced8c53eecb7100787.png" caption="初始文档" >}}

执行格式化

{{< image src="https://webp.slightsnow.com/2024/11/7354b3aac5d95b99ee4b9292713d3728.png" caption="执行格式化" >}}

最终效果

{{< image src="https://webp.slightsnow.com/2024/11/1d711398419d552539230dc450acde44.png" caption="最终效果" >}}


标题、所有文本 Block 都被成功更新了！

注意，Code Block 并没有做处理，这也是符合我们预期的！

## 完整代码

见 [Github 仓库 https://github.com/ideadsnow/notion-auto-format](https://github.com/ideadsnow/notion-auto-format)